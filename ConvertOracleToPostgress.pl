#!/usr/bin/perl

use warnings;
use List::Util 1.33 'any';

local $CurrentFunctionName = "";

local $NextIsFunctionName = 0;

local $CurrentClass = "";

opendir my $dir, "c:/test/decathlon" or die "Cant open directory : $!";

my @files = readdir $dir;
closedir $dir;


foreach my $file (@files)
{

    if ($file =~ m/\.java$/)
    {
        my $xmlfile = "$file";
        ProcessFile($xmlfile);
    }
}

sub ProcessFile {
    my ($file) = @_;

    open (my $fm, "<", "c:\\test\\decathlon\\$file") or die "Can t open file $file";

    my @fileLines = (<$fm>);

    close $fm || die $!;

    print("$file\n");

    my @codeLine;
    foreach my $codeLine (@fileLines) {
        matchDBStuff($codeLine);       
    }


}

sub matchDBStuff() {
    $codeLine = $_[0];
    LookCurrentFunctionAndClass($codeLine);

    inKeyworkList($codeLine);
}

sub LookCurrentFunctionAndClass() {
    $codeLine = $_[0];
    if ( ($matchClass) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]class[ \t]([A-Za-z_][A-Za-z\d_]*)/i)
    {
        $CurrentClass = $matchClass;
        print("Match Class : $CurrentClass\n");
    } 
    else
    {
    # match with or without static (?:[ \t]static[ \t])?
    if ($codeLine =~ m/^[ \t]*(?:private|protected|public)+(?:[ \t]static[ \t])?[ \t]+\b\w+\b/i) 
    {
        $NextIsFunctionName = 1;
        if (
            (($matchFunctionName) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}(?:[ \t]static[ \t]){1}\b\w+\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i) 
          ||
            (($matchFunctionName) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]+\b\w+\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)
        
           )
        {
            print("$codeLine\n");
            print("Match function name : $matchFunctionName\n");
            $CurrentFunctionName = $matchFunctionName;
            print("$CurrentFunctionName\n");
            $NextIsFunctionName = 0;
        }
    }
    
    if ($NextIsFunctionName == 1)
    {
        if ($codeLine =~ /^[ \t]*\b([A-Za-z_][A-Za-z\d_])\b[ \t]*\(/i)
        {
            $CurrentFunctionName = $1;
            print("$CurrentFunctionName\n");
            $NextIsFunctionName = 0;
        }
    }

    }




}


sub inKeyworkList() {

    my ($codeLine) = @_;

    my @DB_KEYWORD = ("SqlQuery", "private", "UPDATE");


    my $found = 0;

    for my $KW (@DB_KEYWORD) {
        if ($codeLine =~ /\b$KW\b/i) {
            $found++;
        }
    }

#    if ($found > 0 ){
#        print("$codeLine\n");
#    }

    return 1;

}


