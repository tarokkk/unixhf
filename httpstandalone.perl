#!/usr/bin/perl
use IO::Socket;
use IPC::Open3;
use Getopt::Std;

#
#Server variables
$port;
$server;
$params;
$host;
#
#Get options
getopt('psch');

#
#Validate options
if( $opt_p > 0 && $opt_p < 65536 )
{
    $port = $opt_p;
}
else
{
    print("Wrong port number: $opt_p\n");
    exit;
}
$server = $opt_s;
$params = $opt_c;
$host = $opt_h;
#
#Server Start LOG
print("HTTP Daemon Started at ");
system(date);
print("HTTP parser:\t\t$server\n".
"Parser arguments:\t$params\n".
"Listening on:\t\t$host:$port\n"
);
$| = 1;
my $socket = new IO::Socket::INET(
				LocalHost => $host,
				LocalPort => $port,
				Proto => 'tcp',
				Listen => 1,
				Reuse => 1,
				);
while( $new_connection = $socket->accept() )
{
	$pid=fork();
	if($pid != 0)
	{
		my($date) = `date`;
		chomp($date);
		print("[$date] - Connected from: " . $new_connection->peerhost() .":" . $new_connection->peerport() . "\n");
		waitpid($pid,0);
		$new_connection->close();
		next;
	}	
	else{
	#Exec httpserver
	open3(\*CHILD_IN,\*CHILD_OUT,\*CHILD_ERR,"$server",
	"$params");
	my($oldselect) = select(CHILD_IN);
	$| = 1;
	select($oldselect);
	$length = 0;
	while(<$new_connection>)
	{
	    print CHILD_IN $_;
	    /Content-Length:/ && do{
		my(@data) = split(/ /,$_);
		$length=$data[1];
	    };
	    if($_  =~ m/^\r?$/)
            {
		if($length > 0)
		{
	 	   my($temp);
		   read( $new_connection , $temp, $length);
		   print CHILD_IN "$temp";
		}
		last;
	    }
	}
	close(CHILD_IN);
	my($oldselect) = select(CHILD_OUT);
        $| = 1;
        select($oldselect);
	while(<CHILD_OUT>)
	{
            print $new_connection $_;
	}
	close(CHILD_OUT);
	close(CHILD_ERR);
	$new_connection->close();
	last;
	}
}

