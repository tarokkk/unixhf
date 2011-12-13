#!/usr/bin/perl 
$| = 1; 
require File::Copy;
$readorexecute = 0;
$baseaddress = "/var/www";
$get_file = "";
$payload = "";
$header_end = 0;
%settings;
#DEBUG
#open(FILEWRITE, "> /home/tarokkk/unixhf/http_dump");

%settings=&LoadSettings($ARGV[0]);
$baseaddress = $settings{'DocumentRoot'};
chomp($baseaddress);
while( <STDIN> )
{
    #DEBUG
#	print FILEWRITE "$_";
    #Split lines at spaces
    @data = split(/ /, $_);
    #Parsing the input
    /^GET/ && do {
        if( $data[1] =~ m/\/$/)
        {
            $get_file = $baseaddress .= "/index.html";
        }
        elsif( $data[1] =~ m/.cgi/ )
        {
            @parsed_get = split(/\?/, $data[1]);
            $filename = $parsed_get[0];
            $get_params = $parsed_get[1];
            #Set environment variable
            $ENV{"REQUEST_METHOD"} = 'GET';
            $ENV{'QUERY_STRING'} = $get_params;
            #Execute script
            $get_file = $baseaddress . $filename;
            $readorexecute = 1;
        }
        else
        {
            $get_file = $baseaddress . $data[1];
        }
    };
    /^POST/ && do {
        $get_file = $baseaddress . $data[1];
        $ENV{"REQUEST_METHOD"} = 'POST';
        $readorexecute = 2;
    };
    /^Content-Length:/ && do {
        $ENV{"CONTENT_LENGTH"}=$data[1];
    };
    /^\r?$/ && do {
        chomp($get_file);
        if( $readorexecute == 2)
        {
            &FileExecuter($get_file);
            last;
        }
        elsif( $readorexecute == 1){
            &FileExecuter($get_file);
            last;
        }		
        else{
            &FileReader($get_file);
            last;
        }
    };
}
if($readorexecute > 1 )
{
#               print("Pay: $payload");
    &FileExecuterPost($get_file,$payload);
    exit;
}


#Functions

#Executing file
sub FileExecuter{
    my ($path) = @_;
    if( -e $path )
    {
        &HTTP_HEAD_OK;
        #Exec script - exit program
        exec($path);
    }
    else
    {
        &HTTP_HEAD_ERR;
    } 
}

#Executing file POST
sub FileExecuterPost{
    my ($path, $line) = @_;
#print("$path and $line");
    if( -e $path ){
#	open(FILEWRITE2, "> /home/tarokkk/unixhf/http_dump_sub");
        &HTTP_HEAD_OK;
        exec($path);
    }
    else
    {
        &HTTP_HEAD_ERR;
    } 
}


#Reading file
sub FileReader{
    my ($path) = @_;
    my ($exist) = 1;
    open(FILE, $path) or $exist = 0;
    if( $exist > 0)
    {
        use File::Copy;
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
        &HTTP_HEAD_ERR;
    }
    exit;
}

#HTTP 200
sub HTTP_HEAD_OK{
    print("HTTP/1.1 200 OK\r\n");
}

#HTTP 404
sub HTTP_HEAD_ERR{
    print("HTTP/1.1 404 FILE NOT FOUND\r\n");
    print("Content-type: text/plain; charset=UTF-8\r\n");
    print("\r\n");
    print("A kért lap nem jeleníthető meg...\n");
    print("\r\n");
}

#Content-type:
sub HTTP_CONTENT_T{
    my ($get_file)=@_;
    print("Content-type: ");
    system("/usr/bin/file -bi $get_file");
#exec("/usr/bin/file -bi $get_file");
}

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

