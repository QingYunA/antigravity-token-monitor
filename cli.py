#!/usr/bin/env python3
import sys
from telemetry_parser import TelemetryParser
from ls_client import LanguageServerClient

def main():
    parser = TelemetryParser()
    ls = LanguageServerClient()

    print("================================================================")
    print("⚡ Antigravity Token 消耗与实时配额统计")
    print("================================================================")

    data = parser.get_all_metrics()
    s = data["summary"]
    t = data["today"]

    print(f"\n📊 【全局总用量统计】 (共 {s['conversations_count']} 个会话, {s['total_steps']} 步)")
    print(f"  • 总计 Token:      {s['total_tokens']:,}")
    print(f"  • 新输入 Token:    {s['prompt_tokens']:,}")
    print(f"  • 缓存命中 Token:  {s['cached_tokens']:,} (节约成本: ${s['saved_usd']} / ¥{s['saved_cny']})")
    print(f"  • 深度思考 Token:  {s['thinking_tokens']:,}")
    print(f"  • 正文输出 Token:  {s['content_tokens']:,}")
    print(f"  • 折算总金额:      ${s['cost_usd']} (约 ¥{s['cost_cny']})")

    print(f"\n📅 【今日用量】")
    print(f"  • 今日总 Token:    {t['total_tokens']:,}")
    print(f"  • 今日折算花费:    ${t['cost_usd']} (约 ¥{t['cost_cny']})")

    print(f"\n🎯 【本地 Language Server 实时限额】")
    quota = ls.get_quota()
    if quota["status"] == "ok":
        for g in quota.get("groups", []):
            print(f"  • {g['displayName']}:")
            for b in g.get("buckets", []):
                rem = b['remainingFraction'] * 100
                print(f"    - {b['displayName']} ({b['window']}): {rem:.1f}% 剩余 | 重置: {b['resetTime']}")
    else:
        print(f"  • 状态: {quota.get('message', '未运行')}")

    print("\n💡 提示: 运行 ./start_monitor.command 可打开图形化 Web 监控页面。")
    print("================================================================")

if __name__ == "__main__":
    main()
