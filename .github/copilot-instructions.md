### Poultry Pal Plus – Application Context

Poultry Pal Plus is a farm management system designed specifically for poultry farmers, particularly in regions with unreliable internet connectivity.

The system helps farmers manage daily operations such as:
- Tracking chicken batches (broilers and layers)
- Managing coops and their lifecycle
- Recording sales (eggs and chickens)
- Tracking mortality and identifying causes
- Recording expenses (feed, medicine, utilities, etc.)
- Managing egg production and packaging
- Handling farm workers and roles
- Managing reminders (vaccination, feeding, medication schedules)
- Generating farm reports
- Sending email summaries and schedules

### Target Users

- Small to medium-scale poultry farmers
- Farm workers with limited technical experience
- Users operating in low or intermittent internet environments

## Project Overview
This is a monorepo for Poultry Pal Plus:
- poultry-pal-service (Spring Boot backend)
- poultry_pal_plus_app (Flutter mobile app)

## Global Rules
- You are a senior full-stack engineer (Spring Boot + Flutter + Web-ready architecture)
- Always produce clean, production-ready, scalable code
- Always ensure backend and frontend stay in sync
- Never break existing contracts without updating all consumers and documenting changes

Cross-System Rule (CRITICAL)
Whenever endpoints or DTOs change:
1. Update backend
2. Update Flutter (API layer, models, UI)
3. Ensure no breaking changes


### Backend (Spring Boot)
- Controller -> Service -> Repository -> Domain
- Use DTOs (never expose entities)
- Use @Valid for validation
- Centralized exception handling
- SOLID principles

### API–Frontend Contract Enforcement
- Update Flutter models & services when backend changes
- Suggest versioning if breaking changes

### Mobile (Flutter)
- Clean architecture
- No business logic in UI
- Strong typing
- Handle nulls safely
- Feature-based structure
- Separate UI, state, and services

## API Contract
All responses:
{
  "success": true,
  "message": "string",
  "data": {}
}

## Coding Standards

### Java
- No business logic in controllers
- Use ResponseEntity
- Clean service layer

### Dart
- Keep widgets small
- No business logic in UI
- Use proper null safety

## Performance
- Avoid N+1 queries
- Use pagination
- Optimize queries

## Security
- Never expose sensitive data
- Validate all inputs

## Testing
- Backend: Unit + Integration + REST Assured
- Mobile: Service + UI tests

## Sync & Consistency
- Handle duplicates
- Eventual consistency
- Prevent stale overwrites

## Copilot Instructions
- Follow existing patterns
- Keep consistency
- Do not introduce unnecessary frameworks

## Summary
Focus on:
- Reliability
- Maintainability
- Scalability