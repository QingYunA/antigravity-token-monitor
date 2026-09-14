import os
import sqlite3
import datetime
from io import BytesIO
from typing import Dict, Any, List, Optional, Tuple

# Official API Pricing (USD per 1M Tokens)
# Reference: Google Cloud Vertex AI & Anthropic Official Tier Pricing
PRICING_TABLE = {
    # Gemini Models
    "gemini-3.8-flash": {"prompt": 0.10, "cached": 0.025, "output": 0.40},
    "gemini-3.7-flash": {"prompt": 0.10, "cached": 0.025, "output": 0.40},
    "gemini-3.6-flash": {"prompt": 0.075, "cached": 0.01875, "output": 0.30},
    "gemini-3.1-pro": {"prompt": 1.25, "cached": 0.3125, "output": 5.00},
    "gemini-1.5-pro": {"prompt": 1.25, "cached": 0.3125, "output": 5.00},
    "gemini-1.5-flash": {"prompt": 0.075, "cached": 0.01875, "output": 0.30},
    # Claude Models
    "claude-sonnet-4-6": {"prompt": 3.00, "cached": 0.30, "output": 15.00},
    "claude-sonnet-3-7": {"prompt": 3.00, "cached": 0.30, "output": 15.00},
    "claude-3-5-sonnet": {"prompt": 3.00, "cached": 0.30, "output": 15.00},
    "claude-opus-4-6": {"prompt": 15.00, "cached": 1.50, "output": 75.00},
    "claude-3-opus": {"prompt": 15.00, "cached": 1.50, "output": 75.00},
    "claude-3-5-haiku": {"prompt": 0.80, "cached": 0.08, "output": 4.00},
    # GPT-OSS / Generic fallback
    "gpt-oss-120b": {"prompt": 0.50, "cached": 0.125, "output": 1.50},
    "default": {"prompt": 0.15, "cached": 0.0375, "output": 0.60},
}

DEFAULT_USD_CNY_RATE = 7.25

def parse_protobuf_varint(buf: bytes, offset: int = 0) -> Tuple[int, int]:
    """Parse a single protobuf varint from buf starting at offset. Returns (value, bytes_consumed)."""
    res = 0
    shift = 0
    idx = offset
    while idx < len(buf):
        b = buf[idx]
        idx += 1
        res |= (b & 0x7F) << shift
        shift += 7
        if not (b & 0x80):
            break
    return res, idx - offset

def _read_varint(stream: BytesIO) -> Optional[int]:
    res = 0
    shift = 0
    while True:
        b = stream.read(1)
        if not b:
            return None
        val = ord(b)
        res |= (val & 0x7F) << shift
        shift += 7
        if not (val & 0x80):
            break
    return res

def extract_step_telemetry(data: bytes) -> Optional[Dict[str, Any]]:
    """
    Extracts step token metrics from gen_metadata blob.
    Protobuf structure discovered:
    field 1 (bytes)
      -> field 4 (bytes):
           field 2: Prompt Tokens (varint)
           field 3: Total Output Tokens (varint)
           field 5: Cached Tokens (varint)
           field 9: Thinking Tokens (varint)
           field 10: Content Tokens (varint)
      -> field 19 (bytes/string): Model ID
    """
    if not data:
        return None

    try:
        stream = BytesIO(data)
        metrics = {
            "prompt_tokens": 0,
            "cached_tokens": 0,
            "output_tokens": 0,
            "thinking_tokens": 0,
            "content_tokens": 0,
            "total_tokens": 0,
            "model": "unknown"
        }
        found_data = False

        while True:
            tag = _read_varint(stream)
            if tag is None:
                break
            fn = tag >> 3
            wt = tag & 7

            if wt == 0:
                _read_varint(stream)
            elif wt == 2:
                length = _read_varint(stream)
                if length is None:
                    break
                subdata = stream.read(length)

                if fn == 1: # Payload
                    s2 = BytesIO(subdata)
                    while True:
                        t2 = _read_varint(s2)
                        if t2 is None:
                            break
                        fn2 = t2 >> 3
                        wt2 = t2 & 7

                        if wt2 == 0:
                            _read_varint(s2)
                        elif wt2 == 2:
                            l2 = _read_varint(s2)
                            if l2 is None:
                                break
                            sub2 = s2.read(l2)

                            if fn2 == 4: # Usage statistics block
                                found_data = True
                                s3 = BytesIO(sub2)
                                while True:
                                    t3 = _read_varint(s3)
                                    if t3 is None:
                                        break
                                    fn3 = t3 >> 3
                                    wt3 = t3 & 7
                                    if wt3 == 0:
                                        val = _read_varint(s3)
                                        if fn3 == 2:
                                            metrics["prompt_tokens"] = val or 0
                                        elif fn3 == 3:
                                            metrics["output_tokens"] = val or 0
                                        elif fn3 == 5:
                                            metrics["cached_tokens"] = val or 0
                                        elif fn3 == 9:
                                            metrics["thinking_tokens"] = val or 0
                                        elif fn3 == 10:
                                            metrics["content_tokens"] = val or 0
                                    elif wt3 == 2:
                                        l3 = _read_varint(s3)
                                        if l3 is not None:
                                            s3.read(l3)
                                    elif wt3 == 1:
                                        s3.read(8)
                                    elif wt3 == 5:
                                        s3.read(4)

                            elif fn2 == 19: # Model name
                                try:
                                    metrics["model"] = sub2.decode("utf-8", "ignore").strip()
                                except Exception:
                                    pass
                        elif wt2 == 1:
                            s2.read(8)
                        elif wt2 == 5:
                            s2.read(4)

            elif wt == 1:
                stream.read(8)
            elif wt == 5:
                stream.read(4)
            else:
                break

        if not found_data:
            return None

        # Reconcile outputs if one was missing
        if metrics["output_tokens"] == 0 and (metrics["thinking_tokens"] > 0 or metrics["content_tokens"] > 0):
            metrics["output_tokens"] = metrics["thinking_tokens"] + metrics["content_tokens"]
        elif metrics["content_tokens"] == 0 and metrics["output_tokens"] > 0:
            metrics["content_tokens"] = max(0, metrics["output_tokens"] - metrics["thinking_tokens"])

        metrics["total_tokens"] = metrics["prompt_tokens"] + metrics["cached_tokens"] + metrics["output_tokens"]
        return metrics
    except Exception:
        return None

def calculate_step_cost(metrics: Dict[str, Any], exchange_rate: float = DEFAULT_USD_CNY_RATE) -> Dict[str, float]:
    """Calculates financial cost for a step given its token metrics."""
    model = metrics.get("model", "default").lower()
    pricing = None
    for k, v in PRICING_TABLE.items():
        if k in model:
            pricing = v
            break
    if not pricing:
        pricing = PRICING_TABLE["default"]

    prompt = metrics.get("prompt_tokens", 0)
    cached = metrics.get("cached_tokens", 0)
    output = metrics.get("output_tokens", 0)

    # Cost per 1M tokens
    cost_prompt = (prompt / 1_000_000.0) * pricing["prompt"]
    cost_cached = (cached / 1_000_000.0) * pricing["cached"]
    cost_output = (output / 1_000_000.0) * pricing["output"]
    total_usd = cost_prompt + cost_cached + cost_output

    # Calculate saved cost due to caching
    potential_without_cache = ((cached + prompt) / 1_000_000.0) * pricing["prompt"] + cost_output
    saved_usd = max(0.0, potential_without_cache - total_usd)

    return {
        "usd": round(total_usd, 6),
        "cny": round(total_usd * exchange_rate, 4),
        "saved_usd": round(saved_usd, 6),
        "saved_cny": round(saved_usd * exchange_rate, 4)
    }

class TelemetryParser:
    def __init__(
        self,
        base_dir: str = "~/.gemini/antigravity",
        exchange_rate: float = DEFAULT_USD_CNY_RATE
    ):
        self.base_dir = os.path.expanduser(base_dir)
        self.conv_dir = os.path.join(self.base_dir, "conversations")
        self.summary_db = os.path.join(self.base_dir, "conversation_summaries.db")
        self.exchange_rate = exchange_rate

    def get_conversation_metadata_map(self) -> Dict[str, Dict[str, Any]]:
        """Reads conversation titles, last modified time, and workspace from conversation_summaries.db"""
        meta_map = {}
        if not os.path.exists(self.summary_db):
            return meta_map

        try:
            conn = sqlite3.connect(f"file:{self.summary_db}?mode=ro", uri=True)
            c = conn.cursor()
            c.execute("""
                SELECT conversation_id, title, last_modified_time, workspace_uris, step_count
                FROM conversation_summaries
            """)
            for row in c.fetchall():
                cid, title, last_mod, w_uris, steps = row
                meta_map[cid] = {
                    "title": title or "Untitled Session",
                    "last_modified": last_mod,
                    "workspace": w_uris or "",
                    "step_count": steps
                }
            conn.close()
        except Exception:
            pass
        return meta_map

    def parse_single_conversation(self, conv_id: str) -> Optional[Dict[str, Any]]:
        db_path = os.path.join(self.conv_dir, f"{conv_id}.db")
        if not os.path.exists(db_path):
            return None

        steps = []
        totals = {
            "prompt_tokens": 0,
            "cached_tokens": 0,
            "thinking_tokens": 0,
            "content_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "cost_usd": 0.0,
            "cost_cny": 0.0,
            "saved_usd": 0.0,
            "saved_cny": 0.0,
        }

        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            c = conn.cursor()
            c.execute("SELECT idx, data FROM gen_metadata ORDER BY idx ASC")
            rows = c.fetchall()
            conn.close()

            primary_model = "unknown"
            for idx, data in rows:
                metrics = extract_step_telemetry(data)
                if not metrics:
                    continue

                cost = calculate_step_cost(metrics, self.exchange_rate)
                step_info = {
                    "step_index": idx,
                    "model": metrics["model"],
                    "prompt_tokens": metrics["prompt_tokens"],
                    "cached_tokens": metrics["cached_tokens"],
                    "thinking_tokens": metrics["thinking_tokens"],
                    "content_tokens": metrics["content_tokens"],
                    "output_tokens": metrics["output_tokens"],
                    "total_tokens": metrics["total_tokens"],
                    "cost_usd": cost["usd"],
                    "cost_cny": cost["cny"],
                    "saved_usd": cost["saved_usd"],
                    "saved_cny": cost["saved_cny"],
                }
                steps.append(step_info)

                if metrics["model"] != "unknown":
                    primary_model = metrics["model"]

                for k in ["prompt_tokens", "cached_tokens", "thinking_tokens", "content_tokens", "output_tokens", "total_tokens"]:
                    totals[k] += metrics[k]
                totals["cost_usd"] += cost["usd"]
                totals["cost_cny"] += cost["cny"]
                totals["saved_usd"] += cost["saved_usd"]
                totals["saved_cny"] += cost["saved_cny"]

            for k in ["cost_usd", "cost_cny", "saved_usd", "saved_cny"]:
                totals[k] = round(totals[k], 4)

            return {
                "conversation_id": conv_id,
                "step_count": len(steps),
                "model": primary_model,
                "totals": totals,
                "steps": steps
            }
        except Exception:
            return None

    def get_all_metrics(self) -> Dict[str, Any]:
        """Scans all conversation databases and compiles global summary, per-model and per-conversation metrics."""
        meta_map = self.get_conversation_metadata_map()
        conv_files = [f[:-3] for f in os.listdir(self.conv_dir) if f.endswith(".db")] if os.path.exists(self.conv_dir) else []

        global_totals = {
            "conversations_count": len(conv_files),
            "total_steps": 0,
            "prompt_tokens": 0,
            "cached_tokens": 0,
            "thinking_tokens": 0,
            "content_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "cost_usd": 0.0,
            "cost_cny": 0.0,
            "saved_usd": 0.0,
            "saved_cny": 0.0,
        }

        now = datetime.datetime.now()
        today_date = now.date()
        seven_days_ago = today_date - datetime.timedelta(days=7)
        thirty_days_ago = today_date - datetime.timedelta(days=30)

        today_totals = {
            "prompt_tokens": 0,
            "cached_tokens": 0,
            "thinking_tokens": 0,
            "content_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "cost_usd": 0.0,
            "cost_cny": 0.0,
            "saved_usd": 0.0,
            "saved_cny": 0.0,
        }

        last_7d_totals = {
            "prompt_tokens": 0,
            "cached_tokens": 0,
            "thinking_tokens": 0,
            "content_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "cost_usd": 0.0,
            "cost_cny": 0.0,
            "saved_usd": 0.0,
            "saved_cny": 0.0,
        }

        last_30d_totals = {
            "prompt_tokens": 0,
            "cached_tokens": 0,
            "thinking_tokens": 0,
            "content_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "cost_usd": 0.0,
            "cost_cny": 0.0,
            "saved_usd": 0.0,
            "saved_cny": 0.0,
        }

        daily_timeline = {}
        for d in range(30):
            day_str = (today_date - datetime.timedelta(days=d)).strftime("%m-%d")
            daily_timeline[day_str] = {"prompt": 0, "cached": 0, "output": 0, "thinking": 0, "cost_usd": 0.0}

        model_breakdown = {}
        conversations_list = []

        for cid in conv_files:
            meta = meta_map.get(cid, {})
            db_path = os.path.join(self.conv_dir, f"{cid}.db")
            mtime = os.path.getmtime(db_path)
            dt = datetime.datetime.fromtimestamp(mtime)
            c_date = dt.date()
            is_today = (c_date == today_date)
            is_7d = (c_date >= seven_days_ago)
            is_30d = (c_date >= thirty_days_ago)

            parsed = self.parse_single_conversation(cid)
            if not parsed or parsed["step_count"] == 0:
                continue

            t = parsed["totals"]
            global_totals["total_steps"] += parsed["step_count"]
            for k in ["prompt_tokens", "cached_tokens", "thinking_tokens", "content_tokens", "output_tokens", "total_tokens"]:
                global_totals[k] += t[k]
                if is_today:
                    today_totals[k] += t[k]
                if is_7d:
                    last_7d_totals[k] += t[k]
                if is_30d:
                    last_30d_totals[k] += t[k]

            day_key = c_date.strftime("%m-%d")
            if day_key in daily_timeline:
                daily_timeline[day_key]["prompt"] += t["prompt_tokens"]
                daily_timeline[day_key]["cached"] += t["cached_tokens"]
                daily_timeline[day_key]["output"] += t["output_tokens"]
                daily_timeline[day_key]["thinking"] += t["thinking_tokens"]
                daily_timeline[day_key]["cost_usd"] += t["cost_usd"]

            global_totals["cost_usd"] += t["cost_usd"]
            global_totals["cost_cny"] += t["cost_cny"]
            global_totals["saved_usd"] += t["saved_usd"]
            global_totals["saved_cny"] += t["saved_cny"]

            if is_today:
                today_totals["cost_usd"] += t["cost_usd"]
                today_totals["cost_cny"] += t["cost_cny"]
                today_totals["saved_usd"] += t["saved_usd"]
                today_totals["saved_cny"] += t["saved_cny"]
            if is_7d:
                last_7d_totals["cost_usd"] += t["cost_usd"]
                last_7d_totals["cost_cny"] += t["cost_cny"]
                last_7d_totals["saved_usd"] += t["saved_usd"]
                last_7d_totals["saved_cny"] += t["saved_cny"]
            if is_30d:
                last_30d_totals["cost_usd"] += t["cost_usd"]
                last_30d_totals["cost_cny"] += t["cost_cny"]
                last_30d_totals["saved_usd"] += t["saved_usd"]
                last_30d_totals["saved_cny"] += t["saved_cny"]

            m_name = parsed["model"]
            if m_name not in model_breakdown:
                model_breakdown[m_name] = {
                    "total_tokens": 0,
                    "prompt_tokens": 0,
                    "cached_tokens": 0,
                    "output_tokens": 0,
                    "cost_usd": 0.0,
                    "cost_cny": 0.0
                }
            model_breakdown[m_name]["total_tokens"] += t["total_tokens"]
            model_breakdown[m_name]["prompt_tokens"] += t["prompt_tokens"]
            model_breakdown[m_name]["cached_tokens"] += t["cached_tokens"]
            model_breakdown[m_name]["output_tokens"] += t["output_tokens"]
            model_breakdown[m_name]["cost_usd"] += t["cost_usd"]
            model_breakdown[m_name]["cost_cny"] += t["cost_cny"]

            conversations_list.append({
                "conversation_id": cid,
                "title": meta.get("title", "Session " + cid[:8]),
                "workspace": meta.get("workspace", ""),
                "last_modified": dt.isoformat(),
                "step_count": parsed["step_count"],
                "model": parsed["model"],
                "totals": t
            })

        # Sort conversations by last_modified descending
        conversations_list.sort(key=lambda x: x["last_modified"], reverse=True)

        for k in ["cost_usd", "cost_cny", "saved_usd", "saved_cny"]:
            global_totals[k] = round(global_totals[k], 4)
            if k in today_totals:
                today_totals[k] = round(today_totals[k], 4)
            if k in last_7d_totals:
                last_7d_totals[k] = round(last_7d_totals[k], 4)
            if k in last_30d_totals:
                last_30d_totals[k] = round(last_30d_totals[k], 4)

        for m in model_breakdown:
            model_breakdown[m]["cost_usd"] = round(model_breakdown[m]["cost_usd"], 4)
            model_breakdown[m]["cost_cny"] = round(model_breakdown[m]["cost_cny"], 4)

        return {
            "summary": global_totals,
            "today": today_totals,
            "last_7d": last_7d_totals,
            "last_30d": last_30d_totals,
            "daily_timeline": [{"day": k, **v} for k, v in reversed(list(daily_timeline.items()))],
            "models": model_breakdown,
            "conversations": conversations_list,
            "exchange_rate": self.exchange_rate,
            "generated_at": datetime.datetime.now().isoformat()
        }
