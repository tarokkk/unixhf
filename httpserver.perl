#!/usr/bin/perl 
use File::Copy;
use IPC::Open3;
#Disable Buffering!
my $old_fh = select(STDOUT);
$| = 1;
select($old_fh);
$old_fh = select(STDIN);
$| = 1;
select($old_fh);

#Determines wheater read/execute a file
$readorexecute = 0;
#
#Variable for the full route for the queried file
$get_file = "";
#
#Indicates the end of the HEADER part
$payload = 0;
#
#Associative array for settings
%settings;

#
#Load setting from file (First command line parameter)
%settings=&LoadSettings($ARGV[0]);
#
#Setting up variables listed in configuration file
$baseaddress = $settings{'DocumentRoot'};
chomp($baseaddress);

$Default_Error_Page=$settings{'DefaultErrorPage'};
$Enable_Cgi=$settings{'EnableCgi'};
@Index_Files=split(/,/ , $settings{'IndexFiles'} );
$LogFile=$settings{'LogFile'};  

while( <STDIN> )
{
    #DEBUG
#	print FILEWRITE "$_";
    #Split lines at spaces
    @data = split(/ /, $_);
    #Parsing the input
    /^GET/ && do {
	#Temorary created route
        my($testing_path) = $baseaddress . $data[1];
	chomp($testing_path);
	#Check if root folder
	if( $data[1] eq "/")
	{
	    $get_file=&GetFolderIndex($data[1]);
	}
	#Check for directory
	elsif( -d $testing_path )
	{
	    $get_file = &GetFolderIndex($data[1]);
	}
	#Check for executable
        elsif( $data[1] =~ m/\.cgi/ )
        {
	    #Check for GET paramaters
            my(@parsed_get) = split(/\?/, $data[1]);
            my($filename) = $parsed_get[0];
            $get_params = $parsed_get[1];
            #Set environment variables
            $ENV{"REQUEST_METHOD"} = 'GET';
            $ENV{'QUERY_STRING'} = $get_params;
            #Execute script
            $get_file = $baseaddress . $filename;
            $readorexecute = 1;
        }
        else
        {
	    #If not Directory/Executable it's a sample html or txt
            $get_file = $baseaddress . $data[1];
        }
    };
    #POST method for CGI
    /^POST/ && do {
        $get_file = $baseaddress . $data[1];
        $ENV{"REQUEST_METHOD"} = 'POST';
        $readorexecute = 2;
    };
    #Set the Content-Length
    /^Content-Length:/ && do {
        $ENV{"CONTENT_LENGTH"}=$data[1];
    };
    #End of HEADER section
    /^\r?$/ && do {
	#Remove \n etc from file route
        chomp($get_file);
        #Execute POST CGI
        if( $readorexecute == 2)
        {
	    #Read (Content_Length) DATA from <STDIN>
	    my($params);
	    read(STDIN, $params, $ENV{'CONTENT_LENGTH'});
	    #Execute Script passing parameters
	    &FileExecuterPost($get_file,$params);
	    last;
        }
	#Execute GET CGI
        elsif( $readorexecute == 1){
            &FileExecuter($get_file);
            last;
        }		
	#Read file
        else{
            &FileReader($get_file);
            last;
        }
    };
    #Get POST Params
}


#Functions

#Executing file
sub FileExecuter{
    my ($path) = @_;
    if( -e $path )
    {
        &HTTP_HEAD_OK;
	#Exec script - exit program
	$pid=open3(\*CHILD_IN,\*CHILD_OUT,\*CHILD_ERR,"$path");
	while(<CHILD_OUT>)
	{
	    print($_);
	}
	waitpid($pid, 0);
	close(CHILD_IN);
	close(CHILD_OUT);
	close(CHIL_ERR);
	exit;
    }
    else
    {
        &HTTP_ERR_HEAD;
    } 
}

#Executing file POST
sub FileExecuterPost{
    my ($path,$params) = @_;
    if( -e $path )                                                                             
    {   
        &HTTP_HEAD_OK;
        #Exec script - exit program
        $pid=open3(\*CHILD_IN,\*CHILD_OUT,\*CHILD_ERR,"$path");
        print CHILD_IN "$params";
	close(CHILD_IN);
        while(<CHILD_OUT>)                                                                     
        {   
            print($_);                                                                         
        }
        waitpid($pid, 0);
        close(CHILD_OUT);                                                                      
        close(CHILD_ERR);
	close(STDIN);
	exit;                                                                                 
    }
    else                                                                                       
    {   
        &HTTP_ERR_HEAD;                                                                        
    } 
}

#Reading file
sub FileReader{
    my ($path) = @_;
    my ($exist) = 1;
    open(FILE, $path) or $exist = 0;
    if( $exist > 0)
    {
        #HTTP_OK
        &HTTP_HEAD_OK
        #Content-type:
        &HTTP_CONTENT_T($path);
        #Header end
        print("\r\n");
        #Copy func to push data on stdout
        copy($path,\*STDOUT);
        close(FILE);
    }
    else
    {
        &HTTP_ERROR_404;
    }
    exit;
}
#
#HTTP 200
sub HTTP_HEAD_OK{
    print("HTTP/1.1 200 OK\r\n");
}
#
#HTTP 404
sub HTTP_ERROR_404{
    my ($exist) = 1;
    my ($path) = $baseaddress . "/" . $Default_Error_Page;
    chomp($path);
    open(FILE, $path) or $exist = 0;
    if( $exist > 0)
    {
	&HTTP_ERR_HEAD;
	&HTTP_CONTENT_T($path);
	print("\r\n");

	copy($path,\*STDOUT);
	close(FILE);
    }
    else
    {
	&HTTP_ERR_HEAD;
        &HTTP_ERR_BODY;
    }
}
sub HTTP_ERR_HEAD{
    print("HTTP/1.1 404 FILE NOT FOUND\r\n");
}
sub HTTP_ERR_BODY{
    print("Content-type: text/plain; charset=UTF-8\r\n");
    print("\r\n");                                                                             
    print("A kért lap nem jeleníthető meg... \n");                                             
    print("\r\n"); 
}
#
#Content-type:
sub HTTP_CONTENT_T{
    my ($get_file)=@_;
    print("Content-type: ");
    system("/usr/bin/file -bi $get_file");
}
#
#Load config file
sub LoadSettings{
    my($cfgfile) = @_;
    open(SETTINGS, "<$cfgfile");
    my (%settings);
    while(<SETTINGS>)
    {
        /^\#/ && do { next;};
        /^[a-zA-Z]/ && do {
            my(@parsed) = split(/ /,$_);
            $settings{$parsed[0]}=$parsed[1];
        };
    }
    close(SETTINGS);
    return %settings;
}

sub GetFolderIndex{
    my($path)=@_;
    my($indexed) = "";
    if( $path =~ m/\/$/ )
    {
	$indexed = $baseaddress.$path."index.html";
    }
    else
    {
	$indexed = $baseaddress.$path."/index.html";
    }
    chomp($indexed);
    return $indexed;

}

