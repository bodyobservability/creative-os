# Vendor Auto-Classifier Table (v1.1+)

This table is intended to produce **~95% auto-green** classifications for typical founder receipts in AI + robotics + imaging.
Use as a deterministic first pass; anything unmatched or ambiguous goes to human triage.

## Outputs
- category (Bundle 02 taxonomy)
- asset_candidate_hint (false | ambiguous | threshold)
- notes

## Rules (Domains)

### AI / Dev / Cloud (auto-green)
| Domain match | Category | Asset candidate | Notes |
|---|---|---:|---|
| openai.com | software_subscriptions.ai_tools | No | ChatGPT / API |
| anthropic.com | software_subscriptions.ai_tools | No | Claude plans |
| openrouter.ai | software_subscriptions.ai_tools | No | API usage |
| cursor.sh / cursor.com | software_subscriptions.developer_tools | No | Cursor |
| jetbrains.com | software_subscriptions.developer_tools | No | IDE licenses |
| adobe.com | software_subscriptions.developer_tools | No | Creative Cloud |
| runpod.io | software_subscriptions.cloud_services | No | GPU compute |
| amazonaws.com | software_subscriptions.cloud_services | No | AWS billing |
| microsoft.com (Azure) | software_subscriptions.cloud_services | No | Azure |

### Electronics supply chain (default expense)
| Domain match | Category | Asset candidate | Notes |
|---|---|---:|---|
| digikey.com | electronics_components | Ambiguous | Mostly supplies |
| mouser.com | electronics_components | Ambiguous | Mostly supplies |
| adafruit.com | electronics_components | No | Supplies |
| sparkfun.com | electronics_components | No | Supplies |
| seeedstudio.com | electronics_components | No | Supplies |

### Imaging / studio (threshold)
| Domain match | Category | Asset candidate | Notes |
|---|---|---:|---|
| bhphotovideo.com | imaging_and_studio | Threshold | Durable gear |
| adorama.com | imaging_and_studio | Threshold | Durable gear |
| profoto.com | imaging_and_studio.lighting | Threshold | Durable |
| godox.* | imaging_and_studio.lighting | Threshold | Durable |

### Marketplaces (require item parse)
| Domain match | Category | Asset candidate | Notes |
|---|---|---:|---|
| amazon.com | needs_item_parse | Threshold | Item-level required |
| ebay.com | needs_item_parse | Threshold | Used gear; review high $ |

### Apple (split: services vs hardware)
| Domain match | Category | Asset candidate | Notes |
|---|---|---:|---|
| apple.com | needs_item_parse | Threshold | Services auto-green; hardware threshold |

## Subject Heuristics
- “subscription”, “renewal”, “monthly” → software_subscriptions.*
- “order”, “shipped”, “delivered” → goods; use vendor + item parsing
- “receipt”, “tax invoice”, “payment successful” → likely deductible; classify by vendor

## Amazon / eBay Item Heuristics
- Auto-green only after line items indicate robotics/imaging and no mixed cart.
- Force review if any single line item > $1,000 or cart contains personal items.
