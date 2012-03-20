require ["fileinto"];

# rule:[Move Spam to Junk Folder]
if header :is "X-Spam-Flag" "YES"
{
    fileinto "Junk";
    stop;
}

