#!/usr/bin/perl
use lib 'C:\Perl64\cpan\build\Class-CSV-1.03-8oD7_P';
use warnings;
use List::Util 1.33 'any';
use Text::CSV;
use File::Find;

local $CurrentFilename = "";
local $CurrentFunctionName = "";
local $CurrentFunctionNameCodeLine = "";

local $NextIsFunctionName = 0;

local $CurrentClass = "";

local $IsInSQLQueryMode = 0;
local $StartFunctionLine = 0;
local $lineIndex = 0;
local $CurrentQueryVariable = "";
local $csv;
local $outCSV;
local $fm;
local $CSVfilename;
local $outMapping;
local $outMappingName;
local $PossibleHardCodedSQL = 0;

local %StartDir = (
     test => "C:\\test\\decathlon"
);

#local %StartDir = (
#     adminFlow => "E:\\Decathlon\\adminflow",
#     adminprod => "E:\\Decathlon\\adminprod",
#     commonprod => "E:\\decathlon\\commonprod\\src",
#     commonscore => "E:\\decathlon\\commonscore\\src",
#     edbflow => "E:\\decathlon\\edbflow",
#     apihpsaw => "E:\\decathlon\\api-hpsaw\\src",
#     edbprod => "E:\\decathlon\\edbprod\\src",
#     extprod => "E:\\decathlon\\extprod\\src",
#     fdtprod => "E:\\decathlon\\fdtprod\\src",
#     flexv4 => "E:\\decathlon\\flexv4",
#     interfaceofferfacade => "E:\\decathlon\\interface-offerfacade",
#     mrgprod => "E:\\decathlon\\mrgprod\\src",
#     order => "E:\\decathlon\\order\\src",
#     orderflow => "E:\\decathlon\\orderflow\\src",
#     pdpconso => "E:\\decathlon\\pdpconso\\src",
#     pilotflow => "E:\\decathlon\\pilotflow\\src",
#     pricing => "E:\\decathlon\\pricing\\src",
#     prodalert => "E:\\decathlon\\prodalert\\src",
#     prodcomapi => "E:\\decathlon\\prodcom-api\\src",
#     prodflow => "E:\\decathlon\\prodflow\\src",
#     prodtower => "E:\\decathlon\\prodtower\\src",
#     prodwsc => "E:\\decathlon\\prodwsc\\src",
#     refprod => "E:\\decathlon\\refprod\\src",
#     scorecapa => "E:\\decathlon\\scorecapa\\src",
#     scorecapac => "E:\\decathlon\\scorecapac\\src",
#     scoreflow => "E:\\decathlon\\scoreflow\\src",
#     scoreflowc => "E:\\decathlon\\scoreflowc\\src",
#     scorepdp => "E:\\decathlon\\scorepdp\\src",
#     scorepdpc => "E:\\decathlon\\scorepdpc\\src",
#     start => "E:\\decathlon\\start\\src",
#     stockflow => "E:\\decathlon\\stockflow\\src",
#     stockprod => "E:\\decathlon\\stockprod\\src"

#);


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
        PARTITION => 0,
        SELECT => 0,
        DELETE => 0,
        UPDATE => 0,
        DUAL => 0,
        ROWID => 0,
        NEXTVAL => 0,

); 
        
local %vQueryVariables = (); 
local %vQuerySQL = (); 






sub ProcessFile {
    $lineIndex = 0;
    $CurrentFunctionName = "";
    $CurrentFunctionNameCodeLine = "";
    $CurrentClass = "";
    $PossibleHardCodedSQL = 0;

    my ($file) = $_[0];

    open ($fm, "<", "$file") or die "Can t open file $file";

    my @fileLines = (<$fm>);

    close $fm || die $!;

    print("$file\n");

    my @codeLine;
    foreach my $codeLine (@fileLines) {
        $lineIndex++;
        IterateLines($codeLine);       
    }
    ProcessFinalStuffForFunction();


}

sub IterateLines() {
    $codeLine = $_[0];
    LookCurrentFunctionAndClass($codeLine);
    ScanSQLQueryObject($codeLine);
    ScanUsageOfQueryObject($codeLine);    
}

sub ScanSQLQueryObject()
{
    $codeLine = $_[0];
    if ( ($sqlQueryVariable) = $codeLine =~ /^[ \t]*(?:final)?[ \t]*(?:SqlQuery){1}[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)
    {
        $vQueryVariables{$sqlQueryVariable} = 1;
        $IsInSQLQueryMode = 1;
        print $outMapping "\n\n$CurrentClass\.$CurrentFunctionName  :  $CurrentFunctionNameCodeLine\n";
    }

    #Scan for Constructor
    if ( $codeLine =~ /(?:new){1}[ \t]+(?:SqlQuery){1}\(\"(.*)\"\)/i)
    {
        $vQuerySQL{$sqlQueryVariable} = $1;
    }

    if  ($codeLine =~ /(?:new){1}[ \t]+(?:SqlQuery){1}\([A-Z][A-Z0-9_]+\)/i) 
    {
        $PossibleHardCodedSQL = 1;
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
            if (  ($sqlQueryVariable) = $codeLine =~ /[ \t]*($oneVariable)\./i)
            {
                if  ($codeLine =~ /[ \t]*($oneVariable)\.\([A-Z][A-Z0-9_]*/i) 
                {
                    $StatisticsOfCurrentFunction{POSSIBLE_HARDCODE_SQL} = 1;
                }  


                if (exists ($vQueryVariables{$sqlQueryVariable}))
                {
                    $occ = () = $codeLine =~ /[ \t]*($oneVariable)\./gi;
                    $vQueryVariables{$sqlQueryVariable} = $vQueryVariables{$sqlQueryVariable} + $occ;
                }
                else
                {
                    $vQueryVariables{$sqlQueryVariable} = 0;
                }
                $CurrentQueryVariable = $sqlQueryVariable;
            }
        }
    }
    
}



sub ProcessAppendQuery()
{
    $codeLine = $_[0];

    if (
        ($codeLine =~ /\.(?:appendQuery|appendToQuery)\("(.*)"\);/i)
        ||
        ($codeLine =~ /\.appendQuery\("(.*)$/i)
        ||
        ($codeLine =~ /\.appendToQuery\("(.*)$/i)

    )
    {
        my $SQL = $1; 
        if (($sqlVar) = $codeLine =~ /([A-Za-z_][A-Za-z\d_]*)\.(?:appendQuery|appendToQuery)/i)
        {
            $vQuerySQL{$sqlVar}  .= $SQL;
        }
        else        
        {
            $vQuerySQL{$CurrentQueryVariable}  .= $SQL;

        }
    }
    # + after appendQuery
    if ($codeLine =~ /[ \t]*\+(.*)/i)
    {
        if ($vQuerySQL{$CurrentQueryVariable})
        {
            $vQuerySQL{$CurrentQueryVariable}  .= $1;
        }
    }    
    

}



sub LookCurrentFunctionAndClass() {
    $codeLine = $_[0];
    if ( ($matchClass) = $codeLine =~ m/^[ \t]*(?:private|protected|public){1}[ \t]+(?:final[ \t]+)?class[ \t]+([A-Za-z_][A-Za-z\d_]*)/i)
    {
        $CurrentFunctionName = "";
        $CurrentFunctionNameCodeLine = "";
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
                (($matchFunctionName) = $codeLine =~ /^[ \t]*(?:private|protected|public){1}[ \t]+(\b[a-zA-Z][\<\>a-zA-Z0-9\]\[]+\b)[ \t]+get/i)
            ||
                #static 
                (($matchFunctionName) = $codeLine =~ /^[ \t]*(?:private|protected|public){1}(?:[ \t]static[ \t]){1}\b[a-zA-Z][a-zA-Z0-9\][<>]*\b[ \t]+([A-Za-z_][A-Za-z\d_]*)/i) 
            ||
                 (($matchFunctionName) = $codeLine =~ /^[ \t]*(?:private|protected|public){1}[ \t]+\b[a-zA-Z][\<\>a-zA-Z0-9\]\[]+\b[ \t]+([A-Za-z_][A-Za-z0-9_]*)/i)
            ||
                 (($matchFunctionName) = $codeLine =~ /^[ \t]*(?:private|protected|public){1}[ \t]+\b[a-zA-Z][a-zA-Z0-9\]\b[ \t]+([A-Za-z_][A-Za-z0-9_]*)/i)
            )
            {
            print("codeline : $codeLine");
                ProcessFinalStuffForFunction();

                $CurrentFunctionName =  "function$lineIndex"; #  "\"$codeLine\"" ;
                $CurrentFunctionNameCodeLine = $codeLine;
                
                ChangeFunction();
                $NextIsFunctionName = 0;
            }
            else
            {
              #not completed function
              $NextIsFunctionName = 0;
            }
        }
        
        if ($NextIsFunctionName == 1)
        {
            if (($matchFunctionName) = $codeLine =~ /(\b[A-Za-z_][A-Za-z\d_]\b)/i)
            {
              ProcessFinalStuffForFunction();
              $CurrentFunctionName =  "function$lineIndex"; 
              $CurrentFunctionNameCodeLine = $codeLine;
              
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

}


sub ProcessFinalStuffForFunction()
{
    print("Process Final Stuff for Current Function : $CurrentFunctionName\n");

    if ($IsInSQLQueryMode == 1)
    {

        @array=keys(%vQuerySQL);
        $size=@array;

        if ($size > 0)
        {
            foreach my $oneSQL (keys %vQuerySQL)
            {
                ScanSQLTEXT($vQuerySQL{$oneSQL});
                print $outMapping "$vQuerySQL{$oneSQL}\n";
            }
            
        }


        #Clear stuff
        $size = 0;

        foreach my $key (keys %vQueryVariables) {
                $size = $size + $vQueryVariables{$key};
        }

        WriteToReport($size);



    }


    foreach my $key (keys %vQueryVariables) {
        delete $vQueryVariables{$key};
    }

    foreach my $key (keys %vQuerySQL) {
        delete $vQuerySQL{$key};
    }

    foreach my $key (keys %vQueryVariables) {
        $vQueryVariables{$key} = 0;
    }

    foreach my $key (keys %StatisticsOfCurrentFunction) {
         $StatisticsOfCurrentFunction{$key} = 0;
    }

    $IsInSQLQueryMode = 0;

    $PossibleHardCodedSQL = 0;
    


}

sub WriteToReport()
{
    $varCount = $_[0];


    my(@datarow) = (
     $CurrentFilename,
     $CurrentClass,
     $CurrentFunctionName,
     $varCount,
     $StatisticsOfCurrentFunction{NVL},
     $StatisticsOfCurrentFunction{NULL},
     $StatisticsOfCurrentFunction{DECODE},
     $StatisticsOfCurrentFunction{SYSDATE},
     $StatisticsOfCurrentFunction{LISTTAG},
     $StatisticsOfCurrentFunction{COUNT},
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
     $StatisticsOfCurrentFunction{ADD_MONTHS},
     $StatisticsOfCurrentFunction{OVERLAPS},
     $StatisticsOfCurrentFunction{PARTITION},
     $StatisticsOfCurrentFunction{SELECT},
     $StatisticsOfCurrentFunction{DELETE},
     $StatisticsOfCurrentFunction{UPDATE},
     $StatisticsOfCurrentFunction{DUAL},
     $StatisticsOfCurrentFunction{ROWID},
     $StatisticsOfCurrentFunction{NEXTVAL},
     $StatisticsOfCurrentFunction{NOT_IN},
     $StatisticsOfCurrentFunction{NOT_EXISTS},
     $StatisticsOfCurrentFunction{CHAR1},
     $StatisticsOfCurrentFunction{INNER_JOIN},
     $StatisticsOfCurrentFunction{NBCHAR},
     $StatisticsOfCurrentFunction{POSSIBLE_HARDCODE_SQL},
     
     
     


      );

    if ($outCSV)
    {
        $csv->print($outCSV, \@datarow);    # Array ref!
    }
    
}

sub ScanSQLTEXT()
{
    $SQLTEXT = $_[0];
    
    my $occ;
    foreach my $statistic (keys %StatisticsOfCurrentFunction)
    {
        $occ = () = $SQLTEXT =~ /\b$statistic\b/gi;
        $StatisticsOfCurrentFunction{$statistic} = $occ;
    }

    $occ = () = $SQLTEXT =~ /NOT IN/gi;
    $StatisticsOfCurrentFunction{NOT_IN} = $occ;
    $occ = () = $SQLTEXT =~ /NOT EXISTS/gi;
    $StatisticsOfCurrentFunction{NOT_EXISTS} = $occ;
    $occ = () = $SQLTEXT =~ /char\(1\)/gi;
    $StatisticsOfCurrentFunction{CHAR1} = $occ;
    $occ = () = $SQLTEXT =~ /inner join/gi;
    $StatisticsOfCurrentFunction{INNER_JOIN} = $occ;

    $StatisticsOfCurrentFunction{NBCHAR} = length($SQLTEXT);
    $StatisticsOfCurrentFunction{POSSIBLE_HARDCODE_SQL} = $PossibleHardCodedSQL;



}




        
foreach my $projectName (keys %StartDir)
{

    my @files;

    find( sub { push @files, $File::Find::name unless -d; },
    $StartDir{$projectName});

    PrepareReport($projectName);

    foreach my $file (@files)
    {
        if ($file =~ m/\.java$/)
        {
            $CurrentFilename = "$file";
            ProcessFile($CurrentFilename);
        }
    }

    CloseReport($projectName);
}






sub PrepareReport() {
    
    $reportFile = $_[0];
    
    $CSVfilename = "c:\\test\\decathlon\\output\\$reportFile.csv";
    my @myField = ("Filename",  "ClassName",  "FunctionName", "VAR NB", "NVL", "NULL", "DECODE", "SYSDATE", "LISTTAG", "COUNT", "UNION", "MAX", "ESCAPE", "ROWNUM", "OVER", "INSTR", "LPAD", "UPPER", "SUM", "FIRST_VALUE", "REPLACE", "ADD_MONTHS", "OVERLAPS", "PARTITION", "SELECT", "DELETE", "UPDATE", "DUAL", "ROWID", "NEXTVAL","NOT IN", "NOT EXISTS", "CHAR(1)", "INNER JOIN", "NB_CHAR", "POSSIBLE HARDCODED SQL");
    open $outCSV, ">:encoding(utf8)", $CSVfilename or die "failed to create $CSVfilename: $!";
    $csv = Text::CSV->new();
    $csv->eol ("\n");
    my (@heading) = @myField;
    $csv->print($outCSV, \@heading);    # Array ref!

    $outMappingName = "c:\\test\\decathlon\\output\\mapping$reportFile.txt";
    open $outMapping, ">:encoding(utf8)", $outMappingName or die "failed to create $outMappingName: $!";


}

sub CloseReport()
{
  
    $reportFile = $_[0];
  
   if ($outCSV) {
    close $outCSV or die "failed to close $CSVfilename: $!";     
   }

   if ($outCSV) {
    close $outMapping or die "failed to close $reportFile: $!";     
   }

}




