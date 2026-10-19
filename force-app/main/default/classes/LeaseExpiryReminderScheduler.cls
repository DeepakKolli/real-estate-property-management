public with sharing class LeaseExpiryReminderScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        sendExpiryReminders();
    }

    public static void sendExpiryReminders() {
        Date todayDate = Date.today();
        Date thirtyDays = todayDate.addDays(30);
        Date oneDay = todayDate.addDays(1);

        List<Lease_Agreement__c> leases = [
            SELECT Id, Name, End_Date__c, Tenant__r.Name, Tenant__r.Email__c,
                   Property__r.Name
            FROM Lease_Agreement__c
            WHERE End_Date__c IN :new Set<Date>{thirtyDays, oneDay}
        ];

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        for (Lease_Agreement__c lease : leases) {
            String tenantEmail = lease.Tenant__r.Email__c;
            if (String.isBlank(tenantEmail)) {
                continue;
            }

            Integer daysLeft = todayDate.daysBetween(lease.End_Date__c);
            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setToAddresses(new String[]{tenantEmail});
            mail.setSubject('Lease expiry reminder: ' + lease.Name);
            mail.setPlainTextBody(
                'Dear ' + lease.Tenant__r.Name + ',\n\n' +
                'This is a reminder that your lease for property ' +
                lease.Property__r.Name + ' (' + lease.Name + ') expires in ' +
                daysLeft + ' day(s), on ' + String.valueOf(lease.End_Date__c) +
                '. Please contact the property manager to discuss renewal.\n\n' +
                'Regards,\nProperty Management'
            );
            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }
}