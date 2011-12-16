#!/usr/bin/perl
use IO::Socket;
use IPC::Open3;
$| = 1;
my $socket = new IO::Socket::INET(
				LocalHost => '127.0.0.1',
				LocalPort => '8080',
				Proto => 'tcp',
				Listen => 1,
				Reuse => 1,
				);
while( $new_connection = $socket->accept() )
{
	$pid=fork();
	if($pid != 0)
	{
		print("New forked connection: $pid\n");
		waitpid($pid,0);
		next;
	}	
	else{
	#Exec httpserver
	open3(\*CHILD_IN,\*CHILD_OUT,\*CHILD_ERR,"/home/tarokkk/unixhf/httpserver.perl",
	"/home/tarokkk/unixhf/httpserver.cfg");
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
		   print CHILD_IN $temp;
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

