require ["fileinto", "vacation"];

# Sample rule of vacation message, disabled by default.
# rule:[Vacation]
if false # true
{
    vacation :days 1 "I'm on vacation.";
}

# rule:[Move Spam to Junk Folder]
if false # header :is "X-Spam-Flag" "YES"
{
    fileinto "Junk";
    stop;
}

