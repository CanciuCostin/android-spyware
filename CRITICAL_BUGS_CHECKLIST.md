# Quick Reference: Critical Bugs by File

## Files with Multiple Critical Issues

### app/middleware/consent_enforcement.rb (3 CRITICAL)
1. **Line 14-15:** Consent disabled in development mode
2. **Line 36-37:** Path traversal bypass via .include?()
3. **Line 43, 53:** Logic error allows bypass on device_id extraction errors

### app/services/mcp/mcp_streaming.rb (2 CRITICAL)
1. **Line 54-98:** Infinite SSE stream resource leak
2. **Line 11, 102:** Thread-unsafe @subscriptions hash

### app/controllers/api/ (4 CRITICAL)
1. **gdpr_controller.rb (1-7):** Missing admin auth on data erasure
2. **preferences_controller.rb (42-46):** Mass assignment via to_unsafe_h
3. **devices_controller.rb (98-106):** IDOR vulnerability
4. **commands_controller.rb (61-78):** Unvalidated command injection

## Immediate Fix Checklist

- [ ] **CRITICAL:** Remove `skip_before_action` from gdpr_controller.rb
- [ ] **CRITICAL:** Fix consent_enforcement.rb - remove dev mode bypass
- [ ] **CRITICAL:** Fix consent_enforcement.rb - use .start_with? instead of .include?
- [ ] **CRITICAL:** Fix consent_enforcement.rb - fail closed on nil device_id
- [ ] **CRITICAL:** Fix devices_controller IDOR - scope to current device
- [ ] **CRITICAL:** Add command whitelist to commands_controller
- [ ] **CRITICAL:** Fix TrackedError.increment_occurrence! race condition
- [ ] **CRITICAL:** Fix Keylog.typing_speed N+1 query
- [ ] **CRITICAL:** Add authentication to ai_pipeline_channel
- [ ] **CRITICAL:** Make MCP @subscriptions thread-safe
- [ ] **CRITICAL:** Add timeout/disconnect detection to MCP SSE streams
- [ ] **CRITICAL:** Whitelist MCP command types
- [ ] **CRITICAL:** Add authentication to MCP command_tools

## Security Review Required

### Controllers Missing Authentication
- alert_rules_controller.rb
- device_groups_controller.rb
- api/geofence_controller.rb

### Parameter Sanitization Issues
- api/preferences_controller.rb (to_unsafe_h)
- api/commands_controller.rb (to_unsafe_h)

### Authorization Bypasses (IDOR)
- api/devices_controller.rb
- api/geofence_controller.rb
- consents_controller.rb

## Database Performance & Integrity

### Race Conditions Requiring Locks
- [ ] app/models/tracked_error.rb:46 (increment_occurrence!)
- [ ] app/models/alert.rb:18 (acknowledge!)
- [ ] app/channels/heartbeat_channel.rb:51 (@missed_pongs)

### N+1 Queries to Optimize
- [ ] app/models/keylog.rb:24 (typing_speed calculation)
- [ ] app/models/device_group.rb:29 (send_command_to_all)

### Missing Validations
- [ ] app/models/notification_log.rb (presence on foreign keys)
- [ ] app/models/upload_chunk.rb (chunk_number <= total_chunks)

## JavaScript Memory Leaks

### Event Listeners Never Removed
- [ ] app/javascript/modules/realtime_dashboard.js:327 (DOMContentLoaded)
- [ ] app/javascript/packs/charts.js:22-28 (date range buttons)
- [ ] app/javascript/packs/instructions.js:87-90 (slider arrows)

### Timers Never Cleared
- [ ] app/javascript/packs/instructions.js:67 (sliderIntervalID)
- [ ] app/javascript/modules/realtime_dashboard.js:267 (reconnectTimer)

## Configuration Fixes

- [ ] config/puma.rb:7 - Change RAILS_MAX_THREADS default to 20
- [ ] config/initializers/content_security_policy.rb - Re-enable CSP

## MCP Server Issues

### Thread Safety
- [ ] app/services/mcp/mcp_server.rb:8-10 (@tools, @resources, @prompts)
- [ ] app/services/mcp/mcp_streaming.rb:11 (@subscriptions)

### Input Validation
- [ ] app/services/mcp/data_tools.rb:38-39 (Time.parse without rescue)
- [ ] app/services/mcp/tools/analysis_tools.rb:37 (unbounded .to_sym)
- [ ] app/services/mcp/prompts/prompt_templates.rb:29 (Date.parse)

### Security
- [ ] app/services/mcp/tools/command_tools.rb:35 (command injection)

## ActionCable Channel Bugs

### Logic Errors
- [ ] app/channels/heartbeat_channel.rb:56 (reject() in callback)
- [ ] app/channels/statistics_channel.rb:18 (find_by id vs device_id)
- [ ] app/channels/location_channel.rb:5,49 (stream name inconsistency)

### Missing Auth
- [ ] app/channels/ai_pipeline_channel.rb:4-11 (no authentication)

### Error Handling
- [ ] app/channels/response_channel.rb:15-16 (silent errors)

---

**Total Issues: 37 bugs (13 Critical, 12 High, 12 Medium)**

**Estimated Fix Time:**
- Phase 1 (Critical): 3-5 days
- Phase 2 (High): 5-7 days  
- Phase 3 (Medium): 3-5 days
