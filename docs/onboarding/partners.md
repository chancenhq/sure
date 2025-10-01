# Partner Onboarding Framework

This guide explains how Maybe's partner onboarding system works and how to configure new partner experiences.

## Data Model Overview

### `users.partner_metadata`
- Users store partner-specific attributes in the `partner_metadata` JSONB column. The column defaults to an empty object.
- Helper methods on `User` simplify access:
  - `user.partner_key`, `user.partner_name`, and `user.partner_type` return normalized values.
  - `user.partner_attribute(:some_key)` looks up any additional metadata stored for that partner.
- Controllers and concerns rely on `partner_key` to decide whether to render partner-specific onboarding or the default Maybe flow.

### Assigning Partner Metadata
- During registration, `PartnerRegistrationsController` merges partner defaults with any submitted `partner_metadata` before saving the user.
- Defaults originate from the partner definition (see below) and ensure keys like `key`, `name`, or `type` are present when expected.
- Existing accounts can be associated with a partner by updating `partner_metadata` (e.g., through the Rails console or admin tooling).

## Partner Configuration

### `config/partners.yml`
- Partners are declared in `config/partners.yml`. Each entry includes:
  - `name` and optional `type` values used for display and reporting.
  - `metadata.required` – which keys must be present for the partner flow.
  - `metadata.defaults` – default metadata values merged onto new registrations.
  - `onboarding.steps` – ordered step identifiers rendered in the partner onboarding wizard.
- The registry loads this configuration for the current environment, making every partner available through `Partners.find(key)`.

### `Partners` Registry
- `Partners.configure` normalizes configuration and instantiates a `Partners::Registry` of `Partners::Definition` objects.
- `Partners.default` returns the first partner in the configuration, used as a fallback when no key is provided.
- Each `Partners::Definition` exposes helper methods:
  - `definition.required_metadata_keys`
  - `definition.default_metadata`
  - `definition.onboarding_steps`
  - `definition.translation("scope", "key")` for localized copy

## Localized Copy and UI

### Translations
- Partner-specific copy lives under `config/locales/partners/*.yml`. Keys mirror the registration and onboarding views.
- When adding a new partner, provide translations in each supported locale under `partners.<partner_key>.*`.

### Views and Controllers
- `PartnerRegistrationsController` renders registration, welcome, and privacy screens tailored to the active partner.
- `PartnerOnboardingsController` drives the multi-step onboarding wizard (`setup`, `preferences`, `goals`, `trial`, etc.), pulling labels and text from translations via the active partner definition.
- The `Onboardable` concern automatically routes users with a `partner_key` to the partner onboarding flow until they finish required steps.

## Selecting the Active Partner
- Partner routes accept a `partner_key` parameter (e.g., `/partners/chancen/onboarding`).
- The application also exposes a `current_partner` helper on `ApplicationController`, which resolves the partner based on the logged-in user's `partner_metadata`.
- Use these helpers to conditionally render partner-specific UI elements or to scope logic to the active partner.

## Adding a New Partner
1. Add the partner entry to `config/partners.yml`, defining metadata defaults, required keys, and onboarding steps.
2. Create localized copy under `config/locales/partners/<locale>.yml` for registration and onboarding content.
3. Update any seed data, invitations, or integrations to assign the correct `partner_metadata[:key]` to new users.
4. Verify that the onboarding wizard renders all configured steps and that registration populates required metadata.

By following these steps, the Maybe app can offer tailored onboarding experiences for multiple partners without duplicating controllers or views.