#!/usr/bin/perl

# hello.pl -- my first perl script!
$date = `date`;

print "Content-type: text/html\n\n";

print <<"EOF";
<HTML>

<HEAD>
<TITLE>Hello, world!</TITLE>
</HEAD>

<BODY>
<H1>Hello, world! - $date</H1>
</BODY>

</HTML>
EOF
