# Privacy Compliance Review - Companion Branch

**Review Date:** 2026-01-30
**Regions of Focus:** Kenya, South Africa, Rwanda
**Applicable Laws:** Kenya Data Protection Act 2019, POPIA (South Africa), Rwanda Law N°058/2021

---

## Executive Summary

This document outlines privacy compliance gaps identified in the `companion` branch and provides recommended policy updates and implementation tasks to address them. The review focuses on requirements for Kenya, South Africa, and Rwanda, which have strict data protection and localization requirements.

---

## Part 1: Privacy Policy Recommended Updates

### 1.1 Data Collection Disclosure (Required for Kenya/SA)

**Current disclosure is incomplete.** Update to include:

```
DATA WE COLLECT

Information You Provide:
- Email address (for account creation and authentication)
- First and last name (for personalization)
- Profile photo (optional)
- Chat conversations with our AI assistant
- Financial goals and preferences you select

Information Collected Automatically:
- IP address (for security and fraud prevention)
- Device information (device type, operating system, browser)
- User agent string (browser identification)
- Session data (login times, session duration)
- Mobile device identifiers (for mobile app users)
- Usage analytics (features used, interaction patterns)
- Error and crash reports (for service improvement)

Information From Third Parties:
- Financial account data (if you connect bank accounts via Plaid or SimpleFin)
- Payment information (processed by Stripe, not stored by us)
```

### 1.2 Third-Party Data Sharing Disclosure

**Current claim of "no sharing" is inaccurate.** Replace with:

```
HOW WE SHARE YOUR DATA

We share data with the following categories of service providers:

AI and Machine Learning Services:
- OpenAI (United States) - Processes chat conversations to provide AI responses
- Langfuse (configurable region) - Monitors AI service quality and performance

Analytics and Monitoring:
- PostHog (United States) - Product analytics to improve user experience
- Sentry (United States/EU) - Error monitoring and crash reporting
- Logtail (configurable) - Application logging for troubleshooting

Infrastructure Services:
- Amazon Web Services or Cloudflare (configurable region) - File storage
- SMTP Provider (configurable) - Email delivery

Financial Data Aggregation (if you choose to connect accounts):
- Plaid Inc. (United States) - Bank account connectivity
- SimpleFin (United States) - Alternative bank connectivity

Payment Processing:
- Stripe (United States) - Subscription payment processing

We require all service providers to maintain appropriate security measures
and only process data according to our instructions.
```

### 1.3 Data Location Disclosure (Required for Kenya/Rwanda)

**Add new section:**

```
WHERE YOUR DATA IS STORED

Primary Data Storage:
Your personal data is stored on servers located in [SPECIFY REGION - e.g.,
"the United States" or "the European Union" or "within Kenya"].

Third-Party Processing Locations:
- AI services (OpenAI, Langfuse): United States
- Analytics (PostHog, Sentry): United States
- File storage: Configurable (default: United States)

Cross-Border Transfers:
When we transfer your data outside of [Kenya/Rwanda/South Africa], we ensure
appropriate safeguards are in place, including:
- Standard contractual clauses approved by relevant data protection authorities
- Adequacy decisions where applicable
- Your explicit consent for specific transfers

[FOR KENYA]: In accordance with the Kenya Data Protection Act 2019, we will
seek approval from the Data Commissioner before transferring personal data
outside Kenya where required.

[FOR RWANDA]: In accordance with Law N°058/2021, personal data may only be
transferred outside Rwanda with appropriate safeguards and, where required,
approval from the National Cyber Security Authority.
```

### 1.4 Data Retention Policy

**Current policy is vague. Replace with specific timelines:**

```
HOW LONG WE KEEP YOUR DATA

Active Accounts:
- Account information: Retained while your account is active
- Chat conversations: Retained for 12 months, then automatically deleted
- Financial data: Retained while your account is active
- Usage analytics: Retained for 24 months

After Account Deletion:
- Account data: Deleted within 30 days of deletion request
- Backups: Purged within 90 days
- Anonymized analytics: May be retained indefinitely

Legal Requirements:
- Financial records: Retained for 7 years as required by law
- Security logs: Retained for 12 months for fraud prevention

Third-Party Retention:
Data shared with third-party services is subject to their retention policies.
We will make reasonable efforts to request deletion from third parties upon
your request.
```

### 1.5 Anonymization Disclosure

**CRITICAL: Remove false anonymization claims. Replace with accurate disclosure:**

```
AI FEATURES AND YOUR DATA

When you use our AI chat assistant:
- Your chat messages are sent to OpenAI to generate responses
- We send a session identifier (not your name or email) with requests
- Chat content is logged by our AI monitoring service (Langfuse) for quality assurance
- Your financial data summaries may be included in AI context

What we DO:
- Use session identifiers instead of your email address
- Encrypt data in transit using TLS
- Limit AI access to only relevant financial summaries

What we DO NOT currently do:
- Remove all identifying information from chat messages
- Prevent third-party AI providers from processing your data
- Guarantee that AI providers do not retain or train on your data

You can disable AI features at any time in your account settings.
```

### 1.6 Data Subject Rights (Kenya/SA/Rwanda)

**Add comprehensive rights section:**

```
YOUR DATA PROTECTION RIGHTS

Under applicable data protection laws, you have the right to:

Access: Request a copy of the personal data we hold about you
Correction: Request correction of inaccurate or incomplete data
Deletion: Request deletion of your personal data
Portability: Receive your data in a machine-readable format
Restriction: Request that we limit how we use your data
Objection: Object to certain types of processing
Withdraw Consent: Withdraw consent at any time (where processing is based on consent)

To exercise these rights, contact us at [privacy@example.com].

Response Times:
- Kenya: We will respond within 30 days
- South Africa: We will respond within 30 days
- Rwanda: We will respond within 30 days

If you are not satisfied with our response, you may lodge a complaint with:
- Kenya: Office of the Data Protection Commissioner
- South Africa: Information Regulator
- Rwanda: National Cyber Security Authority
```

---

## Part 2: Implementation Tickets

### TICKET 1: Implement Actual Chat Anonymization
**Priority:** CRITICAL
**Effort:** Medium (3-5 days)

**Problem:** Consent form claims chat data is anonymized, but no anonymization occurs.

**Implementation:**
```ruby
# app/models/assistant/message_anonymizer.rb
class Assistant::MessageAnonymizer
  def initialize(user, message)
    @user = user
    @message = message
  end

  def anonymize
    anonymized = @message.dup
    # Remove user's name
    anonymized.gsub!(/\b#{Regexp.escape(@user.first_name)}\b/i, "[USER]")
    anonymized.gsub!(/\b#{Regexp.escape(@user.last_name)}\b/i, "[USER]")
    anonymized.gsub!(/\b#{Regexp.escape(@user.email)}\b/i, "[EMAIL]")
    # Remove potential account numbers, phone numbers
    anonymized.gsub!(/\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/, "[CARD]")
    anonymized.gsub!(/\b\d{10,12}\b/, "[ACCOUNT]")
    anonymized
  end
end
```

**Files to modify:**
- `app/models/provider/openai.rb` - Apply anonymization before API calls
- `app/models/assistant/configurable.rb` - Add anonymization to system prompts
- Add tests in `test/models/assistant/message_anonymizer_test.rb`

---

### TICKET 2: Add Data Residency Configuration
**Priority:** HIGH (Required for Kenya/Rwanda)
**Effort:** Medium (3-5 days)

**Problem:** No mechanism to ensure data stays within country borders.

**Implementation:**
```ruby
# config/initializers/data_residency.rb
Rails.configuration.x.data_residency = ActiveSupport::OrderedOptions.new
Rails.configuration.x.data_residency.region = ENV.fetch("DATA_RESIDENCY_REGION", "global")
Rails.configuration.x.data_residency.restrict_cross_border = ENV.fetch("RESTRICT_CROSS_BORDER_TRANSFER", "false") == "true"

# Supported regions: "global", "kenya", "rwanda", "south_africa", "eu"
```

```yaml
# config/storage.yml - Add regional configurations
kenya:
  service: S3
  access_key_id: <%= ENV["S3_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["S3_SECRET_ACCESS_KEY"] %>
  region: af-south-1  # Cape Town (closest to Kenya)
  bucket: <%= ENV["S3_BUCKET"] %>

rwanda:
  service: S3
  access_key_id: <%= ENV["S3_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["S3_SECRET_ACCESS_KEY"] %>
  region: af-south-1
  bucket: <%= ENV["S3_BUCKET"] %>
```

**Database considerations:**
- Deploy database in appropriate region (AWS af-south-1 for Africa)
- Document regional deployment requirements

---

### TICKET 3: Implement Automated Data Retention
**Priority:** MEDIUM
**Effort:** Medium (2-3 days)

**Problem:** No automated data cleanup; data retained indefinitely.

**Implementation:**
```ruby
# app/jobs/data_retention_cleanup_job.rb
class DataRetentionCleanupJob < ApplicationJob
  queue_as :low_priority

  def perform
    # Delete old chat messages (12 months)
    Message.where("created_at < ?", 12.months.ago).destroy_all

    # Delete old sessions (90 days)
    Session.where("created_at < ?", 90.days.ago).destroy_all

    # Delete deactivated users after grace period (30 days)
    User.where(active: false)
        .where("updated_at < ?", 30.days.ago)
        .find_each(&:purge)

    # Log retention actions for audit
    Rails.logger.info("[DataRetention] Cleanup completed at #{Time.current}")
  end
end

# config/initializers/sidekiq.rb - Add cron job
config.cron = {
  'data_retention_cleanup': {
    'cron': '0 2 * * *',  # Daily at 2 AM
    'class': 'DataRetentionCleanupJob'
  }
}
```

---

### TICKET 4: Add Third-Party Data Deletion Mechanism
**Priority:** HIGH (Required for Kenya right-to-deletion)
**Effort:** Large (5-7 days)

**Problem:** Cannot delete user data from third-party services.

**Implementation:**
```ruby
# app/models/user/data_deletion_request.rb
class User::DataDeletionRequest
  def initialize(user)
    @user = user
  end

  def execute
    results = {
      internal: delete_internal_data,
      sentry: request_sentry_deletion,
      posthog: request_posthog_deletion,
      langfuse: request_langfuse_deletion
    }

    DeletionAuditLog.create!(
      user_id: @user.id,
      requested_at: Time.current,
      results: results
    )

    results
  end

  private

  def delete_internal_data
    @user.purge
    { status: :completed }
  end

  def request_sentry_deletion
    # Sentry GDPR deletion API
    # https://docs.sentry.io/api/
    { status: :manual_required, instructions: "Submit deletion request via Sentry dashboard" }
  end

  def request_posthog_deletion
    # PostHog supports programmatic deletion
    # https://posthog.com/docs/privacy/data-deletion
    if $posthog
      $posthog.capture({
        distinct_id: @user.id,
        event: '$delete_person'
      })
      { status: :requested }
    else
      { status: :not_configured }
    end
  end

  def request_langfuse_deletion
    # Document manual process
    { status: :manual_required, instructions: "Contact Langfuse support" }
  end
end
```

---

### TICKET 5: Update Consent Form with Accurate Disclosures
**Priority:** CRITICAL
**Effort:** Small (1 day)

**Problem:** Current consent form makes false claims and omits required disclosures.

**Files to modify:**
- `config/locales/views/partner_registrations/en.yml`
- `app/views/partner_registrations/consent.html.erb`

**Changes required:**
1. Remove claim that chats are "anonymised"
2. Add automatic data collection disclosure (IP, device info)
3. Add third-party service disclosure
4. Add data location disclosure
5. Add specific retention periods
6. Add cross-border transfer notice for Kenya/Rwanda

---

### TICKET 6: Disable Sentry PII Collection
**Priority:** HIGH
**Effort:** Small (< 1 day)

**Problem:** Sentry configured to send PII without disclosure.

**Implementation:**
```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # CHANGE: Disable PII collection
  config.send_default_pii = false

  # Add explicit scrubbing
  config.before_send = lambda do |event, hint|
    # Scrub sensitive data
    event.request&.headers&.delete("Authorization")
    event.request&.headers&.delete("Cookie")
    event.user&.ip_address = nil
    event
  end
end
```

---

### TICKET 7: Add User Data Export Endpoint
**Priority:** MEDIUM (Supports data portability right)
**Effort:** Small (1-2 days)

**Problem:** Data export exists but no user-facing endpoint.

**Implementation:**
```ruby
# app/controllers/settings/data_exports_controller.rb
class Settings::DataExportsController < ApplicationController
  def create
    export = Current.family.family_exports.create!(
      status: :pending,
      requested_by: Current.user
    )

    DataExportJob.perform_later(export)

    redirect_to settings_privacy_path,
      notice: t(".export_requested")
  end
end
```

Add route and UI in settings for users to request their data.

---

### TICKET 8: Create Data Processing Agreements Register
**Priority:** MEDIUM
**Effort:** Documentation only

**Required DPAs:**
1. OpenAI - AI Processing Agreement
2. Sentry - Data Processing Addendum
3. PostHog - Data Processing Agreement
4. Langfuse - Data Processing Agreement
5. AWS/Cloudflare - Data Processing Addendum
6. Stripe - Data Processing Agreement
7. Plaid - Data Processing Agreement (if used)
8. SimpleFin - Data Processing Agreement (if used)

**Action:** Legal team to obtain and file DPAs with each provider.

---

### TICKET 9: Encrypt Chat Content at Rest
**Priority:** MEDIUM
**Effort:** Medium (2-3 days)

**Problem:** Chat messages stored in plain text.

**Implementation:**
```ruby
# app/models/message.rb
class Message < ApplicationRecord
  encrypts :content  # Add Active Record Encryption

  belongs_to :chat
  # ...
end
```

**Migration:**
```ruby
class EncryptMessageContent < ActiveRecord::Migration[7.2]
  def up
    # Encrypt existing messages
    Message.find_each do |message|
      message.update_column(:content, message.content)
    end
  end
end
```

---

### TICKET 10: Add Privacy Settings Page
**Priority:** MEDIUM
**Effort:** Medium (2-3 days)

**Implementation:**
Create user-facing privacy controls:
- Toggle AI features on/off
- Toggle analytics collection
- Request data export
- Request account deletion
- View data processing summary

---

## Part 3: Compliance Checklist

### Kenya Data Protection Act 2019

| Requirement | Status | Ticket |
|------------|--------|--------|
| Lawful basis for processing | Partial - needs explicit consent updates | #5 |
| Purpose limitation disclosure | Missing | #5 |
| Data minimization | Partial | - |
| Accuracy | OK | - |
| Storage limitation | Missing automated retention | #3 |
| Security (encryption) | Partial - chat not encrypted | #9 |
| Cross-border transfer controls | Missing | #2 |
| Right to access | Missing user endpoint | #7 |
| Right to deletion | Partial - third parties not covered | #4 |
| Data breach notification | Not reviewed | - |

### South Africa POPIA

| Requirement | Status | Ticket |
|------------|--------|--------|
| Accountability | Missing DPA register | #8 |
| Processing limitation | Missing clear purpose | #5 |
| Purpose specification | Missing | #5 |
| Information quality | OK | - |
| Openness | Missing complete disclosure | #5 |
| Security safeguards | Partial | #6, #9 |
| Data subject participation | Missing user controls | #7, #10 |

### Rwanda Law N°058/2021

| Requirement | Status | Ticket |
|------------|--------|--------|
| Consent requirements | Partial | #5 |
| Data localization | Missing | #2 |
| Cross-border transfer approval | Missing | #2 |
| Right to erasure | Partial | #4 |
| Security measures | Partial | #6, #9 |

---

## Recommended Implementation Order

1. **Immediate (Week 1):**
   - Ticket #5: Update consent form (removes legal liability)
   - Ticket #6: Disable Sentry PII (quick security win)

2. **Short-term (Weeks 2-3):**
   - Ticket #1: Implement chat anonymization (addresses false claims)
   - Ticket #4: Third-party deletion mechanism

3. **Medium-term (Weeks 4-6):**
   - Ticket #2: Data residency configuration
   - Ticket #3: Automated retention
   - Ticket #7: User data export endpoint
   - Ticket #9: Encrypt chat content

4. **Ongoing:**
   - Ticket #8: DPA documentation
   - Ticket #10: Privacy settings page

---

## Appendix: Key File Locations

| File | Purpose |
|------|---------|
| `config/locales/views/partner_registrations/en.yml` | Consent form text |
| `app/views/partner_registrations/consent.html.erb` | Consent form view |
| `config/initializers/sentry.rb` | Error monitoring config |
| `config/initializers/posthog.rb` | Analytics config |
| `config/initializers/langfuse.rb` | AI logging config |
| `app/models/provider/openai.rb` | OpenAI integration |
| `app/models/user.rb` | User deletion logic |
| `app/models/family/data_exporter.rb` | Data export logic |
| `config/storage.yml` | File storage config |
| `config/environments/production.rb` | Production settings |
