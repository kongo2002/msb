#!/usr/bin/env python3

import json
import sys
from datetime import datetime, timezone


def reset_info_for(ts):
    if not ts:
        return ""
    try:
        dt = datetime.fromtimestamp(float(ts), tz=timezone.utc)
        secs = int((dt - datetime.now(timezone.utc)).total_seconds())
    except (TypeError, ValueError):
        return ""
    if secs <= 0:
        return ""
    days, rem = divmod(secs, 86400)
    h, m = rem // 3600, (rem % 3600) // 60
    if days > 0:
        return f"{days}d {h}h" if h > 0 else f"{days}d"
    return f"{h}h {m}min" if h > 0 else f"{m}min"


def quota_segment(label, used, resets_at):
    if used is None:
        return ""
    rem = round(100 - used)
    reset_info = reset_info_for(resets_at)
    suffix = f" (reset in {reset_info})" if reset_info else ""
    return f" \033[0;35m{label}: {rem}% left{suffix}\033[0m"


def main():
    data = json.load(sys.stdin)

    model = (data.get("model") or {}).get("display_name") or "Claude"
    used = (data.get("context_window") or {}).get("used_percentage")

    rate_limits = data.get("rate_limits") or {}
    five_hour = rate_limits.get("five_hour") or {}
    seven_day = rate_limits.get("seven_day") or {}

    out = []

    if used is not None:
        used_int = round(used)
        bar_width = 20
        filled = used_int * bar_width // 100
        bar = "#" * filled + "-" * (bar_width - filled)
        out.append(f"\033[0;36m{model}\033[0m [{bar}] \033[0;33m{used_int}%\033[0m")
    else:
        out.append(f"\033[0;36m{model}\033[0m")

    quota = quota_segment(
        "5h", five_hour.get("used_percentage"), five_hour.get("resets_at")
    )
    quota += quota_segment(
        "7d", seven_day.get("used_percentage"), seven_day.get("resets_at")
    )

    if quota:
        out.append(f" |{quota}")

    sys.stdout.write("".join(out))


if __name__ == "__main__":
    main()
