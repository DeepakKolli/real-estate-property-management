System.schedule(
    'Daily Lease Expiry Reminders',
    '0 0 8 * * ?',
    new LeaseExpiryReminderScheduler()
);
