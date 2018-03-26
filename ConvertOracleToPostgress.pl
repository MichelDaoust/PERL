#!/usr/bin/perl

use warnings;
use List::Util 1.33 'any';

local $CurrentFunctionName = "";

local $NextIsFunctionName = 0;

local $CurrentClass = "";

local $IsInSQLQueryMode = 0;
local $StartFunctionLine = 0;
local $lineIndex = 0;
local $CurrentQueryVariable = "";


local %StatisticsOfCurrentFunction = ( 
        "NVL" => 0,
        "DateTime" => 0,
        "BLOB" => 0,
        "LOC" => 0,
        "SQLQueryOccurence" => 0,
        "StringBuilderOccurence" => 0,
        "COUNT" => 0,

          
                                    );

local %vQueryVariables = (); 
local %vQuerySQL = (); 



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
    if ( ($sqlQueryVariable) = $codeLine =~ m/^[ \t]*(?:final)?[ \t]*(?:SqlQuery){1}[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)
    {
        $vQueryVariables{$sqlQueryVariable} = 0;
        $IsInSQLQueryMode = 1;
    }

    #Scan for Constructor
    if ( $codeLine =~ /(?:new){1}[ \t]+(?:SqlQuery){1}\(\"(.*)\"\)/i)
    {
        $vQuerySQL{$sqlQueryVariable} = $1;
        print("%%%%%%%%%%%%%%%%%%%%%%%%%%%% SQL: $CurrentSQL");
    }


}



sub ScanUsageOfQueryObject()
{
    $codeLine = $_[0];

    if ($IsInSQLQueryMode == 1)
    {
        ScanLineWhenQueryIsON($codeLine);


        foreach my $oneVariable (keys %vQueryVariables)
         {
            # look for a variable usage (ex :vQuery.{something})
            if ( ($sqlQueryVariable) = $codeLine =~ m/[ \t]*($oneVariable)\./i)
            {
                if (exists ($vQueryVariables{$sqlQueryVariable}))
                {
                    $vQueryVariables{$sqlQueryVariable} = $vQueryVariables{$sqlQueryVariable} + 1;
                }
                else
                {
                    $vQueryVariables{$sqlQueryVariable} = 0;
                }
                $CurrentQueryVariable = $sqlQueryVariable;
                ProcessQueryVariable($codeLine, $sqlQueryVariable);
            }
        }
    }
    
}


sub ScanLineWhenQueryIsON()
{
    $codeLine = $_[0];
    
    if ($codeLine =~ /\.appendQuery/i)
    {
   
        ProcessAppendQuery($codeLine);
   
        $StatisticsOfCurrentFunction{"SQLQueryOccurence"} = $StatisticsOfCurrentFunction{"SQLQueryOccurence"} + 1;  
    }
    if ($codeLine =~ /NVL/i)
    {
     #   print("SCANLINE : $codeLine\n");
        $StatisticsOfCurrentFunction{"NVL"} = $StatisticsOfCurrentFunction{"NVL"} + 1;  
    }
    if ($codeLine =~ /count/i)
    {
        $StatisticsOfCurrentFunction{"COUNT"} = $StatisticsOfCurrentFunction{"COUNT"} + 1;  
        
    }
    
}


sub ProcessAppendQuery()
{
    $codeLine = $_[0];

    if ($codeLine =~ /\.appendQuery\("(.*)"\);/i)
    {
        my $SQL = $1; 
        if ($codeLine =~ /([A-Za-z_][A-Za-z\d_]*)\.appendQuery/i)
        {
            $vQuerySQL{$1}  .= $SQL;
        }
        else
        {
            $vQuerySQL{$CurrentQueryVariable}  .= $SQL;

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
    if ( ($matchClass) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]class[ \t]([A-Za-z_][A-Za-z\d_]*)/i)
    {
        $CurrentClass = $matchClass;
        print("Match Class : $CurrentClass\n");
        $NextIsFunctionName = 0;
    } 
    else
    {
        # match with or without static (?:[ \t]static[ \t])?
        if ($codeLine =~ m/^[ \t]*(?:private|protected|public)+(?:[ \t]static[ \t])?[ \t]+\b\w+\b/i) 
        {
            $matchFunctionName = "";
            if (  #get
                (($matchFunctionName) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]+\b([a-zA-Z][a-zA-Z0-9\][<>]*)\b[ \t]+(?:get){1}/i)
            ||
                #static 
                (($matchFunctionName) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}(?:[ \t]static[ \t]){1}\b[a-zA-Z][a-zA-Z0-9\][<>]*\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i) 
            ||
                 (($matchFunctionName) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]+\b[a-zA-Z][a-zA-Z0-9\][<>]*\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)

            )
            {
                ProcessFinalStuffForFunction();
                $CurrentFunctionName = $codeLine;
                ChangeFunction();
                $NextIsFunctionName = 0;
            }
            else
            {
              #not completed function
              $NextIsFunctionName = 1;
            }
        }
        
        if ($NextIsFunctionName == 1)
        {
#            if ($codeLine =~ /^[ \t]*\b([A-Za-z_][A-Za-z\d_])\b[ \t]*\(/i)
              ProcessFinalStuffForFunction();
              $CurrentFunctionName = $codeLine;
              ChangeFunction();
              $NextIsFunctionName = 0;
        }

    }
}



sub ChangeFunction()
{

    $StartFunctionLine = $lineIndex;
    print("New Function : $CurrentFunctionName\n");

    foreach my $key (keys %vQueryVariables) {
        delete $vQueryVariables{$key};
    }

    foreach my $key (keys %vQuerySQL) {
        delete $vQuerySQL{$key};
    }

    $CurrentSQL = "";
    $CurrentQueryVariables = "";
    $IsInSQLQueryMode = 0;
    $StatisticsOfCurrentFunction{NVL} = 0;
    $StatisticsOfCurrentFunction{DateTime} = 0;
    $StatisticsOfCurrentFunction{BLOB} = 0;
    $StatisticsOfCurrentFunction{LOC} = 0;
    $StatisticsOfCurrentFunction{SQLQueryOccurence} = 0;
    $StatisticsOfCurrentFunction{COUNT} = 0;
}


sub ProcessFinalStuffForFunction()
{
    print("Process Final Stuff for Current Function : $CurrentFunctionName\n");
    print("StartFunctionLine : $StartFunctionLine\n");

    foreach my $oneVariable (keys %vQueryVariables)
    {
       print(" -------------VQUERYVARIABLE COUNT : $vQueryVariables{$oneVariable}\n");
    }

    foreach my $oneSQL (keys %vQuerySQL)
    {
       print(" ********************************SQL : $vQuerySQL{$oneSQL}\n");
    }


}


