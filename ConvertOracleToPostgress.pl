#!/usr/bin/perl
use lib 'C:\Perl64\cpan\build\Class-CSV-1.03-8oD7_P';
use warnings;
use List::Util 1.33 'any';
use Text::CSV;

local $CurrentFilename = "";
local $CurrentFunctionName = "";

local $NextIsFunctionName = 0;

local $CurrentClass = "";

local $IsInSQLQueryMode = 0;
local $StartFunctionLine = 0;
local $lineIndex = 0;
local $CurrentQueryVariable = "";


local %StatisticsOfCurrentFunction = (
        NVL  => 0,
        NULL => 0,
        DECODE => 0,
        SYSDATE => 0,
        LISTTAG => 0,
        COUNT => 0,
        UNION => 0,
        MAX => 0,
        ESCAPE => 0,
        ROWNUM => 0,
        OVER => 0,
        INSTR => 0,
        LPAD => 0,
        UPPER => 0,
        SUM => 0,
        FIRST_VALUE => 0,
        REPLACE => 0,
        ADD_MONTHS => 0,
        OVERLAPS => 0,
        PARTITION => 0
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
        $CurrentFilename = "$file";
        ProcessFile($CurrentFilename);
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
    if ( ($sqlQueryVariable) = $codeLine =~ /^[ \t]*(?:final)?[ \t]*(?:SqlQuery){1}[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)
    {
        $vQueryVariables{$sqlQueryVariable} = 0;
        $IsInSQLQueryMode = 1;
    }

    #Scan for Constructor
    if ( $codeLine =~ /(?:new){1}[ \t]+(?:SqlQuery){1}\(\"(.*)\"\)/i)
    {
        $vQuerySQL{$sqlQueryVariable} = $1;
    }


}



sub ScanUsageOfQueryObject()
{
    $codeLine = $_[0];

    if ($IsInSQLQueryMode == 1)
    {
        ProcessAppendQuery($codeLine);

        foreach my $oneVariable (keys %vQueryVariables)
         {
            # look for a variable usage (ex :vQuery.{something})
            if ( ($sqlQueryVariable) = $codeLine =~ /[ \t]*($oneVariable)\./i)
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
                (($matchFunctionName) = $codeLine =~ /^[ \t]*(?:private|protected|public){1}[ \t]+\b([a-zA-Z][a-zA-Z0-9\][<>]*)\b[ \t]+(?:get){1}/i)
            ||
                #static 
                (($matchFunctionName) = $codeLine =~ /^[ \t]*(?:private|protected|public){1}(?:[ \t]static[ \t]){1}\b[a-zA-Z][a-zA-Z0-9\][<>]*\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i) 
            ||
                 (($matchFunctionName) = $codeLine =~ /^[ \t]*(?:private|protected|public){1}[ \t]+\b[a-zA-Z][a-zA-Z0-9\][<>]*\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)

            )
            {
                ProcessFinalStuffForFunction();
                $CurrentFunctionName = $matchFunctionName;
                ChangeFunction();
                $NextIsFunctionName = 0;
            }
            else
            {
              #not completed function
              $NextIsFunctionName = "";
            }
        }
        
        if ($NextIsFunctionName == 1)
        {
            if (($matchFunctionName) = $codeLine =~ /(\b[A-Za-z_][A-Za-z\d_]\b)/i)
            {
              ProcessFinalStuffForFunction();
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

    foreach my $key (keys %vQueryVariables) {
        delete $vQueryVariables{$key};
    }

    foreach my $key (keys %vQuerySQL) {
        delete $vQuerySQL{$key};
    }

    foreach my $key (keys %vQueryVariables) {
        $vQueryVariables{$key} = 0;
    }

    $IsInSQLQueryMode = 0;
}


sub ProcessFinalStuffForFunction()
{
    print("Process Final Stuff for Current Function : $CurrentFunctionName\n");


    @array=keys(%vQuerySQL);
    $size=$#array;

    if ($size > 0)
    {
        foreach my $oneSQL (keys %vQuerySQL)
        {
            ScanSQLTEXT($vQuerySQL{$oneSQL});
        }
    }
    else
    {
        foreach my $oneVariable (keys %vQueryVariables)
        {
            $StatisticsOfCurrentFunction{"VAR:$oneVariable"} = $vQueryVariables{$oneVariable};
        }
    }

    ProcessReport();

}

sub ProcessReport()
{
    my $filename = "c:\\test\\decathlon\\output2.csv";
    my @myField = ("filename",  "className",  "functionName", "NVL", "NULL", "DECODE", "SYSDATE", "LISTTAG", "COUNT", "UNION", "MAX", "ESCAPE", "ROWNUM", "OVER", "INSTR", "LPAD", "UPPER", "SUM", "FIRST_VALUE", "REPLACE", "NOTEXISTS", "ADD_MONTHS", "OVERLAPS", "PARTITION");

    open my $fh, ">:encoding(utf8)", $filename or die "failed to create $filename: $!";
    $csv = Text::CSV->new();
    $csv->eol ("\n");
    my (@heading) = @myField;
    $csv->print($fh, \@heading);    # Array ref!


    my(@datarow) = (
     $CurrentFilename,
     $CurrentClass,
     $CurrentFunctionName,
     $StatisticsOfCurrentFunction{NVL},
     $StatisticsOfCurrentFunction{NULL},
     $StatisticsOfCurrentFunction{DECODE},
     $StatisticsOfCurrentFunction{SYSDATE},
     $StatisticsOfCurrentFunction{LISTTAG},
     $StatisticsOfCurrentFunction{COUNT},
     $StatisticsOfCurrentFunction{NVL},
     $StatisticsOfCurrentFunction{UNION},
     $StatisticsOfCurrentFunction{MAX},
     $StatisticsOfCurrentFunction{ESCAPE},
     $StatisticsOfCurrentFunction{ROWNUM},
     $StatisticsOfCurrentFunction{OVER},
     $StatisticsOfCurrentFunction{INSTR},
     $StatisticsOfCurrentFunction{LPAD},
     $StatisticsOfCurrentFunction{UPPER},
     $StatisticsOfCurrentFunction{SUM},
     $StatisticsOfCurrentFunction{FIRST_VALUE},
     $StatisticsOfCurrentFunction{REPLACE},
     $StatisticsOfCurrentFunction{NOTEXISTS},
     $StatisticsOfCurrentFunction{ADD_MONTHS},
     $StatisticsOfCurrentFunction{OVERLAPS},
     $StatisticsOfCurrentFunction{PARTITION}
      );

    $csv->print($fh, \@datarow);    # Array ref!
  
   close $fh or die "failed to close $filename: $!";     
    
}

sub ScanSQLTEXT()
{
    $SQLTEXT = $_[0];
    
    my $occ;
    foreach my $statistic (keys %StatisticsOfCurrentFunction)
    {
        $occ = () = $SQLTEXT =~ /$statistic/gi;
        $StatisticsOfCurrentFunction{$statistic} = $occ;
        print ("STATS : $statistic : $occ\n");
    }

    $occ = () = $SQLTEXT =~ /NOT IN/gi;
    $StatisticsOfCurrentFunction{NOT_IN} = $occ;
    $occ = () = $SQLTEXT =~ /char\(1\)/gi;
    $StatisticsOfCurrentFunction{CHAR1} = $occ;
    

    
     

}



