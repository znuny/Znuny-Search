# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Search::ES::IndexQueueDataProcess;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Search::Object',
    'Kernel::System::Search',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description(
        'Process queued index data operations.'
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{SearchObject} = $Kernel::OM->Get('Kernel::System::Search');

    if (
        $Self->{SearchObject}
        && $Self->{SearchObject}->{Error}
        &&
        $Self->{SearchObject}->{Error}->{Configuration}->{Disabled}
        )
    {
        $Self->Print("<yellow>Search configuration is disabled. Exiting.\n</yellow>");
        $Self->{Exit} = 1;
        return 1;
    }

    if ( !$Self->{SearchObject} || $Self->{SearchObject}->{Error} ) {
        my $Message = "Errors occured. Exiting.";
        if ( !$Self->{SearchObject}->{ConnectObject} ) {
            $Message = "Could not connect to the cluster.";
        }
        $Self->Print("<red>$Message\n</red>");
        $Self->{Abort} = 1;
        return;
    }

    return 1;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return $Self->ExitCodeOk()    if ( $Self->{Exit} );
    return $Self->ExitCodeError() if ( $Self->{Abort} );
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');

    my @ActiveIndexes;
    my @IndexList = $Self->{SearchObject}->IndexList();

    # execute only on registered indexes that exists in the cluster
    INDEX:
    for my $IndexRealName (@IndexList) {
        my $IndexName = $SearchChildObject->IndexIsValid(
            IndexName => $IndexRealName,
            RealName  => 1,
        );

        push @ActiveIndexes, $IndexName if $IndexName;
    }

    my $RebuildedObjectQueries = {
        Failed  => 0,
        Success => 0,
    };

    INDEX:
    for my $IndexName (@ActiveIndexes) {

        my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");

        $SearchIndexObject->ObjectIndexQueueHandle(
            IndexName              => $IndexName,
            RebuildedObjectQueries => $RebuildedObjectQueries,
        );
    }

    $Self->Print(
        "<green>Successfully executed $RebuildedObjectQueries->{Success} object queries for Elasticsearch.</green>\n"
    );
    if ( $RebuildedObjectQueries->{Failed} ) {
        $Self->Print(
            "<red>Execution of $RebuildedObjectQueries->{Failed} object queries failed for Elasticsearch.\n</red>\n"
        );
    }

    return $Self->ExitCodeOk();
}

1;
