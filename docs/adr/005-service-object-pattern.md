# ADR-005: Service Object Pattern

**Date:** 2024-01-15  
**Status:** Accepted

## Context

As EagleSpy grew, controller actions became bloated with business logic —
command dispatch, response parsing, file handling, and notification delivery
were all inlined. Fat controllers are hard to test, difficult to reuse, and
violate the Single Responsibility Principle.

Alternatives considered:
- **Concerns only** — Rails concerns help with shared behavior but still
  couple logic to controllers.
- **Interactor / Command pattern gem** — gems like `interactor` or `dry-rb`
  add abstractions but introduce dependencies and learning curve.
- **Background jobs only** — Sidekiq jobs are great for async work but
  shouldn't own business logic that also needs synchronous execution.

## Decision

Adopt a **plain-Ruby service object** convention with a base
`ApplicationService` class and a `Result` wrapper.

Conventions:
1. Services live in `app/services/`.
2. Each service has a single public entry point: `.call` or `.process`.
3. Services return a `Result` object (`success?`, `data`, `error`).
4. Services are stateless — all dependencies are injected via constructor or
   method arguments.
5. Specialized processors extend a common interface (e.g.,
   `ContactsResponseProcessor`, `SmsResponseProcessor`).

Example — `ResponseProcessor` dispatch:
```ruby
COMMAND_PROCESSORS = {
  'get_contacts' => ContactsResponseProcessor,
  'get_sms'      => SmsResponseProcessor,
  # ... 28 command types
}.freeze

def self.process(data)
  processor_class = COMMAND_PROCESSORS[command_type]
  processor_class.new(pending_command, payload).process
end
```

## Consequences

### Positive
- Controllers become thin coordinators; easy to test in isolation.
- Services are reusable across controllers, channels, and background jobs.
- Clear ownership — each command type has exactly one processor.
- `Result` wrapper provides a consistent success/failure interface.

### Negative
- More files to navigate; newcomers must learn the `app/services/` layout.
- No framework-enforced contract — discipline is required to keep services
  consistent.
- Some services still grow large; periodic refactoring is needed.
