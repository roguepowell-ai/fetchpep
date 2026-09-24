---
authority: claude-proposes
---

# Costs

Ceiling: **£200/month.** Figures below are from planning and are unverified against a bill.

## Setup — about £135 in year one

| Item | |
|---|---|
| Apple Developer | ~£78/yr |
| Google Play Console | ~£20 once |
| Android developer verification | ~£20 once |
| Sprite editor | ~£17 once |
| Android test device | not yet bought |

## Running — about £11/month at ten test users

The Nakama VM is **100% of it**. Every other service sits inside a free tier at that scale.
Apple amortised takes it to roughly £18/month.

Worth knowing rather than changing: co-presence is a premise, not a hypothesis, so the VM
stays.

## Where the risk actually is

**Egress, not compute.** Cloudflare sits in front and R2 has zero egress, which removes the
unbounded line item and also replaces the global load balancer, Cloud CDN and Cloud Armor.

[certain] R2 charges per Class B (read) operation. Bundle sprites into atlases — one
request per creature, not one per frame.

[certain] Cloud Run defaults to 100 max instances, and an instance holding an open
WebSocket bills as active for as long as it is held. Cap it explicitly.

## Controls

1. **Billing kill switch** — Pub/Sub to a Cloud Function that detaches billing. Applied
   before the game goes public; during the pilot, budget alerts are the only guard (D-072).
2. Budget alerts email while the meter still runs. They are a warning, not a control.
3. Spend limits set explicitly on every managed service at creation.
4. `require_partition_filter = TRUE` on every partitioned BigQuery table.
