# bugzilla_invoices
Script for automating the creation and sending of invoices from time entries in bugzilla.

Calls the bugzilla timereport.py program. See https://github.com/AJRepo/bugzilla_timereports
Assumes bugzilla timereport.py is at /usr/local/bin/timereport.py 
And takes the output of it and generates an invoice which is emailed to clients. 

```
Usage: create_invoice.sh <flags see below>
   -a              Additional arguments to pass to timereports.py (e.g. --begin_date)
   -b <EMAIL>      Email to use for BCC: email/report
   -c <CLIENT>     Bugzilla Product (client)
   -d              Debug Mode: Will also call timereports.py in Debug Mode
   -e <ENDSIGN>    The name at the end, the person signing the invoice.
   -f <EMAIL>      Email to use for From: email/report
   -h              Help (this message)
   -i              Call timereports.py in Invoice Mode
   -m <number>     Number of (Hosted) Machines (Containers) to charge for
   -n              Dry Run. Do not send emails
   -o <ORG>        Organization/Company
   -p <number>     Percent Discount on Rate per hour
   -q              Quiet. Send email only. Do not print to screen
   -r <number>     Rate per hour to charge
   -s <SALUTATION> The Hello string for reports
   -t <EMAIL>      Email to use for To: email/report
```

You can use cursor control sequences to get multi-line text variables.
  E.g. -e $'Your Friend\nAJO' 

Example: (-n flag gives no-email output) 

```
        $./create_invoice.sh -r 100 -p 10 -m 10 -i -t client@example.com -c 'Bugzilla Product 1' \
        -s 'Dear Valued Customer:' -f me@example.com -a '--begin_date=last_month' \
        -o 'My Example Company' -n -e $'ajotest\nMy title here'

        Dry Run mode is ON No email will be sent.
        Dear Valued Customer:

        Your invoice and details follow:
        ------------------------------------------------------------
        Time Summary from 2021-10-01 to 2021-10-31
        ------------------------------------------------------------
        #914 : CONFIRMED       : Title from Ticket 914
        #928 : CONFIRMED       : Title from Ticket 928
             :                 :   which continues on the next line
        #934 : RESOLVED        : Title from Ticket 934
             :                 :   which continues on the next line
        #935 : RESOLVED        : Title from Ticket 935
        #936 : RESOLVED        : Title from Ticket 936
             :                 :   which continues on the next line
        ------------------------------------------------------------
           Item    :              Description              : Quantity  :    Rate    :  Amount
        Consulting : Tickets from 2021-10-01 to 2021-10-31 : 15.90 hrs : $100.00/hr :  $1590.00
         Discount  :                                       :           :     10.00% : ($ 159.00)
          Hosting  :          10 Hosted Service Items      :    10 VMs : $ 30.00/vm : $  300.00
        No charge for research

        TOTAL=$1731.00

        Thank you for your business, we appreciate it very much

        Sincerely,
        ajotest
        My title here
        My Example Company
```
