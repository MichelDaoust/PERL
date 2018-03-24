#!/usr/bin/perl

use warnings;
use List::Util 1.33 'any';

local $CurrentFunctionName = "";

local $NextIsFunctionName = 0;

local $CurrentClass = "";

local $IsInSQLQueryMode = 0;
local $StartFunctionLine = 0;
local $lineIndex = 0;


local %StatisticsOfCurrentFunction = ( 
        "NVL" => 0,
        "DateTime" => 0,
        "BLOB" => 0,
        "LOC" => 0,
        "SQLQueryOccurence" => 0,
        "StringBuilderOccurence" => 0,

          
                                    );

local %vQueryVariables = (); 



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
        $lineIndex++;
        matchDBStuff($codeLine);       
    }
    ProcessFinalStuffForFunction();  #Last function to process on the file 


}

sub matchDBStuff() {
    $codeLine = $_[0];
    LookCurrentFunctionAndClass($codeLine);
    ScanSQLQueryObject($codeLine);
    ScanUsageOfQueryObject($codeLine);    

 #   inKeyworkList($codeLine);
}

sub ScanSQLQueryObject()
{
    $codeLine = $_[0];
    if ( ($sqlQueryVariable) = $codeLine =~ m/^[ \t]*(?:SqlQuery){1}[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)
    {
        $vQueryVariables{$sqlQueryVariable} = 0;
        $IsInSQLQueryMode = 1;
    }


}

sub ScanUsageOfQueryObject()
{
    $codeLine = $_[0];

    if ($IsInSQLQueryMode == 1)
    {
        foreach my $oneVariable (keys %vQueryVariables)
         {
            # look for a variable usage (ex :vQuery.{something})
            if ( ($sqlQueryVariable) = $codeLine =~ m/^[ \t]*($oneVariable)\./i)
            {
                if (exists ($vQueryVariables{$sqlQueryVariable}))
                {
                    $vQueryVariables{$sqlQueryVariable} = $vQueryVariables{$sqlQueryVariable} + 1;
                }
                else
                {
                    $vQueryVariables{$sqlQueryVariable} = 0;
                }
                ProcessQueryVariable($codeLine, $sqlQueryVariable);
            }
        }
    }
    
}


sub ProcessQueryVariable()
{
    $codeLine = $_[0];
    $sqlVariable =  $_[1]; 

    if ($codeLine =~ m/[ \s]+(?:NVL|TIMESTAMP){1}[\s]/i)
    {
        print ("Example of a SQLQueryVariable $sqlVariable with Specific Keyword : $codeLine");
    }
    


}



sub LookCurrentFunctionAndClass() {
    $codeLine = $_[0];
    if ( ($matchClass) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]class[ \t]([A-Za-z_][A-Za-z0-9_]*)/i)
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
                (($matchFunctionName) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}(?:[ \t]static[ \t]){1}\b[a-zA-Z][a-zA-Z0-9<>]*\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i) 
            ||
                 (($matchFunctionName) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]+\b[a-zA-Z][a-zA-Z0-9<>]*\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)
            )
            {
                ProcessFinalStuffForFunction();
                $CurrentFunctionName = $matchFunctionName;
                ChangeFunction();
                $NextIsFunctionName = 0;
            }
        }
        
        if ($NextIsFunctionName == 1)
        {
            if ($codeLine =~ /^[ \t]*\b([A-Za-z_][A-Za-z\d_])\b[ \t]*\(/i)
            {
                $CurrentFunctionName = $1;
                ChangeFunction();
                $NextIsFunctionName = 0;
            }
        }

    }
}



sub ChangeFunction()
{

    $StartFunctionLine = $lineIndex;
    print("New Function : $CurrentFunctionName\n");


    %{$vQueryVariables} = ();


    $IsInSQLQueryMode = 0;
    $StatisticsOfCurrentFunction{NVL} = 0;
    $StatisticsOfCurrentFunction{DateTime} = 0;
    $StatisticsOfCurrentFunction{BLOB} = 0;
    $StatisticsOfCurrentFunction{LOC} = 0;
    $StatisticsOfCurrentFunction{SQLQueryOccurence} = 0;
}


sub ProcessFinalStuffForFunction()
{
    print("Process Final Stuff for Current Function : $CurrentFunctionName\n");
    print("StartFunctionLine : $StartFunctionLine");

    foreach my $oneVariable (keys %vQueryVariables)
    {
       print(" -------------VQUERYVARIABLE COUNT : $vQueryVariables{$oneVariable}\n");
    }
}


