# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Search::TestPerformance;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Search',
    'Kernel::System::DB',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Test performance.');

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $Self->{SearchObject} = $Kernel::OM->Get('Kernel::System::Search');

    if ( !$Self->{SearchObject} || $Self->{SearchObject}->{Error} ) {
        my $Message = "Errors occured. Exiting.";
        if ( !$Self->{SearchObject}->{ConnectObject} ) {
            $Message = "Could not connect to the cluster. Exiting.";
        }
        $Self->Print("<red>$Message\n</red>");
        return $Self->ExitCodeError();
    }

    return 1;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ObjectToTest = 'ArticleDataMIME';

    my %Params = (
        Objects     => [$ObjectToTest],
        QueryParams => {},
        Limit       => 100302,
    );

    # engine search
    my $GeneralStartTime = Time::HiRes::time();
    my $Search           = $Self->{SearchObject}->Search(
        %Params,
    );
    my $GeneralStopTime             = Time::HiRes::time();
    my $AdvCallGeneralExecutionTime = sprintf( "%.6f", $GeneralStopTime - $GeneralStartTime );
    my $PerformanceTestResult       = "Advanced call time: $AdvCallGeneralExecutionTime seconds - ES\n";

    # fallback search
    $GeneralStartTime = Time::HiRes::time();
    my $FallbackSearch = $Self->{SearchObject}->Search(
        %Params,
        UseSQLSearch => 1,
    );
    $GeneralStopTime = Time::HiRes::time();
    my $AdvCallGeneralExecutionTimeFallback = sprintf( "%.6f", $GeneralStopTime - $GeneralStartTime );

    # clean sql search
    $PerformanceTestResult .= "Advanced call time: $AdvCallGeneralExecutionTimeFallback seconds - fallback\n";
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    $GeneralStartTime = Time::HiRes::time();
    my @QueryResponse;
    return if !$DBObject->Prepare(
        SQL => "SELECT * FROM article_data_mime",
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @QueryResponse, \@Row;
    }
    $GeneralStopTime = Time::HiRes::time();

    my $PrepareTime = sprintf( "%.6f", $GeneralStopTime - $GeneralStartTime );
    $PerformanceTestResult .= "Clean SQL: $PrepareTime seconds - clean SQL\n";

    my $ResultsCount = {
        Engine   => scalar @{ $Search->{$ObjectToTest} },
        Fallback => scalar @{ $FallbackSearch->{$ObjectToTest} },
        CleanSQL => scalar @QueryResponse,
    };

    $Self->Print("<yellow>Performance results:</yellow>\n");
    $Self->Print("<yellow>--$PerformanceTestResult\n\n</yellow>");
    $Self->Print("<yellow>Results count: \n</yellow>");
    $Self->Print("<yellow>Engine: $ResultsCount->{Engine}\n</yellow>");
    $Self->Print("<yellow>Fallback: $ResultsCount->{Fallback}\n</yellow>");
    $Self->Print("<yellow>CleanSQL: $ResultsCount->{CleanSQL}\n</yellow>");

    return $Self->ExitCodeOk();
}

1;
