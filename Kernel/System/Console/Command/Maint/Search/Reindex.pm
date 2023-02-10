# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Search::Reindex;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
    'Kernel::System::PID',
    'Kernel::System::Cache',
    'Kernel::System::JSON',,
    'Kernel::System::Search::Admin::Reindexation',
    'Kernel::System::Search::Cluster',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description(
        'Re-index all data for specified indexes. This includes deleting all specified index data first.'
    );
    $Self->AddOption(
        Name        => 'index',
        Description => "Index to re-index.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.+/,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'force',
        Description => "Re-index even when there is another re-indexation process in progress.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name => 'recreate',
        Description =>
            "(default|latest) Before re-indexing, delete and add all specified indexes again with default or latest settings instead of clearing their data.",
        Required   => 0,
        HasValue   => 1,
        ValueRegex => qr/\A(default|latest)\z/,
        Multiple   => 0,
    );
    $Self->AddOption(
        Name => 'check-data-equality',
        Description =>
            "Before reindexing check if search engine indexes are equal with SQL DB.",
        Required => 0,
        HasValue => 0,
        Multiple => 0,
    );
    $Self->AddOption(
        Name => 'cluster-reinitialize',
        Description =>
            "Run cluster initialization process without checking if cluster was initialized previously.",
        Required => 0,
        HasValue => 0,
        Multiple => 0,
    );
    $Self->AddOption(
        Name => 'limit',
        Description =>
            "Limit reindexed data. Used mostly for testing.",
        Required   => 0,
        HasValue   => 1,
        Multiple   => 0,
        ValueRegex => qr/\A\d+\z/,
    );
    $Self->AddOption(
        Name => 'start-from',
        Description =>
            "Start re-indexing from specified object id.",
        Required   => 0,
        HasValue   => 1,
        Multiple   => 0,
        ValueRegex => qr/\A\d+\z/,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{SearchObject} = $Kernel::OM->Get('Kernel::System::Search');

    if ( !$Self->{SearchObject} || $Self->{SearchObject}->{Error} ) {
        my $Message = "Errors occured. Exiting.";
        if ( !$Self->{SearchObject}->{ConnectObject} ) {
            $Message = "Could not connect to the cluster.";
        }
        $Self->Print("<red>$Message\n</red>");
        $Self->{Abort} = 1;
    }

    return 1;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return $Self->ExitCodeError() if ( $Self->{Abort} );
    my $SearchChildObject  = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $PIDObject          = $Kernel::OM->Get('Kernel::System::PID');
    my $CacheObject        = $Kernel::OM->Get('Kernel::System::Cache');
    my $JSONObject         = $Kernel::OM->Get('Kernel::System::JSON');
    my $ReindexationObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Reindexation');
    my $ClusterObject      = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');

    my $ClusterReinitialize = $Self->GetOption('cluster-reinitialize');
    my $CheckDataEquality   = $Self->GetOption('check-data-equality');
    my $Recreate            = $Self->GetOption('recreate');
    my $Limit               = $Self->GetOption('limit');
    my $StartFrom           = $Self->GetOption('start-from');

    $Self->{Index} = $Self->GetOption('index');

    if ( !IsArrayRefWithData( $Self->{Index} ) ) {
        @{ $Self->{Index} } = sort keys %{ $Self->{SearchObject}->{Config}->{RegisteredIndexes} };

        if ( !IsArrayRefWithData( $Self->{Index} ) ) {
            $Self->Print("No index found in SearchEngine::Loader::Index config.\n");
            return $Self->ExitCodeError();
        }
    }

    my $ForcePID = $Self->GetOption('force') // 0;

    %{ $Self->{ReindexingProcess} } = $PIDObject->PIDGet(
        Name => 'SearchEngineReindex',
    );

    if ( IsHashRefWithData( $Self->{ReindexingProcess} ) ) {
        $Self->Print("<yellow>There is already a locked re-indexing process\n</yellow>");
        return $Self->ExitCodeError() if !$ForcePID;

        $Self->Print("Are you sure about trying to stop the process and continue (y/n)?\n");

        my $Agreement = <STDIN>;    ## no critic
        chomp $Agreement;

        if ( $Agreement && $Agreement ne 'y' ) {
            return $Self->ExitCodeOk();
        }

        $Self->Print(
            "<yellow>Used force flag, trying to remove ongoing process with ID $Self->{ReindexingProcess}->{PID}.</yellow>\n"
        );

        my $Success = kill 9, $Self->{ReindexingProcess}->{PID};
        if ($Success) {
            $Self->Print("<yellow>Process was stopped</yellow>\n");
        }
        else {
            $Self->Print("Could not stop process, are you about to continue (y/n)?\n");

            $Agreement = <STDIN>;    ## no critic
            chomp $Agreement;

            if ( $Agreement && $Agreement ne 'y' ) {
                return $Self->ExitCodeOk();
            }
        }
    }

    $Self->{ClusterConfig} = $ClusterObject->ActiveClusterGet();

    my $Success = $ReindexationObject->DataEqualitySet(
        ClusterID     => $Self->{ClusterConfig}->{ClusterID},
        Indexes       => $Self->{Index},
        NoPermissions => 1,
    );

    $Self->{SearchObject} = $Kernel::OM->Get('Kernel::System::Search');

    my $EqualityDataStatus = $ReindexationObject->DataEqualityGet(
        ClusterID => $Self->{ClusterConfig}->{ClusterID}
    );

    my %IndexObjectStatus;
    my @Objects;
    if ( IsArrayRefWithData( $Self->{Index} ) ) {
        my $Counter = 0;

        INDEX:
        for my $Index ( @{ $Self->{Index} } ) {

            # check index validity on Znuny side
            my $Result = $SearchChildObject->IndexIsValid(
                IndexName => $Index,
                RealName  => 0,
            );

            if ( !$Result ) {
                $Self->Print("<red>Index $Index is not valid! Ignoring re-indexation for this index.\n</red>");
                $Counter++;
                next INDEX;
            }

            if (
                $EqualityDataStatus->{$Index}->{Percentage}
                && $EqualityDataStatus->{$Index}->{Percentage} == 100
                && $CheckDataEquality
                )
            {
                $Self->Print("<green>Index $Index has 100% data equality, skipping...\n</green>");
                $Counter++;
                next INDEX;
            }

            $Counter++;

            # add index to reindex query
            $IndexObjectStatus{$Index} = {
                Successful => 0,
            };

            push @Objects, $Index;
        }
    }

    $Self->{Started} = 1;

    $PIDObject->PIDCreate(
        Name  => 'SearchEngineReindex',
        Force => $ForcePID,
    );

    my $ObjectQueueJSON = $JSONObject->Encode(
        Data => \%IndexObjectStatus
    );

    $CacheObject->Set(
        Type  => 'ReindexingProcess',
        Key   => 'ReindexingQueue',
        Value => $ObjectQueueJSON,
        TTL   => 24 * 60 * 60,
    );

    $Self->{SearchObject}->ClusterInit(
        Force => $ClusterReinitialize,
    );

    # list all indexes on remote (engine) side
    my @ActiveClusterRemoteIndexList = $Self->{SearchObject}->IndexList();
    my $ReindexationSettings         = $ConfigObject->Get('SearchEngine::Reindexation')->{Settings};

    my $ReindexationStep = $ReindexationSettings->{ReindexationStep} // 500;

    OBJECT:
    for my $IndexName (@Objects) {
        $Self->Print("<yellow>-----\n</yellow>");
        $Self->Print("<yellow>Re-indexing $IndexName</yellow>\n");
        $Self->Print("<yellow>--\n</yellow>");

        my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");

        # get real name index name from sysconfig
        my $IndexRealName = $Self->{SearchObject}->{Config}->{RegisteredIndexes}->{$IndexName};

        # check if real name index on remote side exists
        my $RemoteExists = grep { $_ eq $IndexRealName } @ActiveClusterRemoteIndexList;

        $CacheObject->Set(
            Type  => 'ReindexingProcess',
            Key   => 'Percentage',
            Value => 0,
            TTL   => 24 * 60 * 60,
        );

        $CacheObject->Set(
            Type  => 'ReindexingProcess',
            Key   => 'ReindexedIndex',
            Value => $IndexName,
            TTL   => 24 * 60 * 60,
        );

        if ( !$RemoteExists ) {
            my $IndexRealName = $SearchIndexObject->{Config}->{IndexRealName};

            $Self->Print(
                "<yellow>$IndexName index is valid in Znuny, but does not exist in the search engine.\n"
                    .
                    "Index in search engine with real name \"$IndexRealName\" as \"$IndexName\" (friendly name in Znuny) will be created.\n\n</yellow>"
            );

            my $AddSuccess = $Self->{SearchObject}->IndexAdd(
                IndexName => $IndexName,
            );
        }
        elsif ($Recreate) {
            my $IndexSettings = {};
            if ( $Recreate eq 'latest' ) {
                $IndexSettings = $Self->{SearchObject}->IndexInitialSettingsGet(
                    Index => $IndexName,
                );
            }

            my $RemoveSuccess = $Self->{SearchObject}->IndexRemove(
                IndexName => $IndexName,
            );

            if ( !$RemoveSuccess ) {
                $Self->Print(
                    "<red>Could not remove index $IndexName! Ignoring re-indexation for that index.\n</red>"
                );
                next OBJECT;
            }

            my $AddSuccess = $Self->{SearchObject}->IndexAdd(
                IndexName => $IndexName,
                Settings  => $IndexSettings,
            );

            if ( !$AddSuccess ) {
                $Self->Print(
                    "<red>Could not add index $IndexName! Ignoring re-indexation for that index.\n</red>"
                );
                next OBJECT;
            }
            else {
                $Self->Print("<green>Index recreated succesfully.\n</green>");
            }

        }
        else {
            # clear whole index to reindex it correctly
            my $ClearSuccess = $Self->{SearchObject}->IndexClear(
                Index => $IndexName,
            );

            if ( !$ClearSuccess ) {
                $Self->Print(
                    "<red>Could not clear index $IndexName data! Ignoring re-indexation for that index.\n</red>"
                );
                next OBJECT;
            }
        }

        # initialize index
        my $InitSuccess = $Self->{SearchObject}->IndexInit(
            Index => $IndexName,
        );

        if ( !$InitSuccess ) {
            $Self->PrintError("Can't initialize index $IndexName!\n");
            $IndexObjectStatus{$IndexName}->{Successful} = 0;
            next OBJECT;
        }

        $Self->Print("<green>Index initialized.</green>\n<yellow>Adding indexes..</yellow>\n");

        my $ObjectCount = $SearchIndexObject->ObjectListIDs(
            ResultType => 'COUNT',
        );

        if ( !($ObjectCount) ) {
            $Self->Print(
                "<yellow>No data to re-index.</yellow>\n\n"
            );
            $Self->Print("<green>Done.</green>\n");
            $IndexObjectStatus{$IndexName}->{Successful} = 1;
            next OBJECT;
        }

        my $LastObjectID = $StartFrom ? [$StartFrom] : $SearchIndexObject->ObjectListIDs(
            ResultType => 'ARRAY',
            OrderBy    => 'DESC',
            Limit      => defined $Limit ? $Limit : 1
        );

        if ( !( IsArrayRefWithData($LastObjectID) ) ) {
            $Self->Print(
                "<red>Couldn't find last object id.</red>\n\n"
            );
            $IndexObjectStatus{$IndexName}->{Successful} = 0;
            next OBJECT;
        }

        my $GeneralStartTime = Time::HiRes::time();
        my $ObjectIDs;

        my $From;
        my $Refresh         = 0;
        my $IterationNumber = 1;
        my $EndID;

        if ($StartFrom) {
            $EndID = defined $Limit ? $LastObjectID->[0] - $Limit : 1;
        }
        else {
            $EndID = defined $Limit ? $LastObjectID->[0] - $Limit : 1;
        }

        my $StartID = $LastObjectID->[0];
        $EndID = 1 if ( $EndID < 1 );

        my $ReindexationRange = $ReindexationStep > $StartID - $EndID ? $StartID - $EndID + 1 : $ReindexationStep;

        my $TotalCount = $StartID - $EndID + 1;
        STEP:
        for ( my $i = $StartID; $i >= $EndID; $i = $i - $ReindexationRange ) {

            my $From = $i;
            my $To   = $i - $ReindexationRange + 1;

            if ( $To < $EndID ) {
                $To = $EndID;
                $IterationNumber += $From - $To;
            }
            else {
                $IterationNumber += $ReindexationRange;
            }

            $To = 1 if ( $To < 1 );

            my @ArrayPiece;
            for ( my $j = $From; $j >= $To; $j-- ) {
                push @ArrayPiece, $j;
            }

            my $Result = $Self->{SearchObject}->ObjectIndexAdd(
                Index    => $IndexName,
                ObjectID => \@ArrayPiece,
                Refresh  => 0,
                Reindex  => 1,
                Silent   => 1,
            );

            my $Percent = int( $IterationNumber / ( scalar $TotalCount / 100 ) );

            my $ReindexingQueue = $CacheObject->Get(
                Type => 'ReindexingProcess',
                Key  => 'ReindexingQueue',
            );

            if ( !$ReindexingQueue ) {
                my $ObjectQueueJSON = $JSONObject->Encode(
                    Data => \%IndexObjectStatus
                );

                $CacheObject->Set(
                    Type  => 'ReindexingProcess',
                    Key   => 'ReindexingQueue',
                    Value => $ObjectQueueJSON,
                    TTL   => 24 * 60 * 60,
                );

                $CacheObject->Set(
                    Type  => 'ReindexingProcess',
                    Key   => 'ReindexedIndex',
                    Value => $IndexName,
                    TTL   => 24 * 60 * 60,
                );
            }

            my $Seconds = abs( int( $GeneralStartTime - Time::HiRes::time() ) );

            if (
                ( ( $Seconds % 5 == 0 && $Refresh != $Seconds ) || $Seconds - $Refresh > 5 )
                && $Percent != 100
                )
            {
                $Refresh = $Seconds;
                $Self->Print(
                    "<yellow>$IterationNumber</yellow> of <yellow>$TotalCount</yellow> processed (<yellow>$Percent %</yellow> done).\n"
                );
            }

            $CacheObject->Set(
                Type  => 'ReindexingProcess',
                Key   => 'Percentage',
                Value => $Percent,
                TTL   => 24 * 60 * 60,
            );

            $IndexObjectStatus{$IndexName}->{ObjectFails} += scalar @ArrayPiece if !defined $Result;
        }

        $Self->Print(
            "<yellow>$TotalCount</yellow> of <yellow>$TotalCount</yellow> processed (From object ID: $StartID to $EndID, <yellow>100%</yellow> done).\n"
        );

        $CacheObject->Set(
            Type  => 'ReindexingProcess',
            Key   => 'Percentage',
            Value => 100,
            TTL   => 24 * 60 * 60,
        );

        $Self->Print("<green>Done.</green>\n\n");
        $IndexObjectStatus{$IndexName}->{Successful} = 1;
    }

    $Self->Print("\n<yellow>Summary:</yellow>\n");
    if ( keys %IndexObjectStatus ) {
        for my $Index ( sort keys %IndexObjectStatus ) {
            $Self->Print("\nIndex: $Index\n");

            $Self->Print("Status: ");
            if ( $IndexObjectStatus{$Index}->{Successful} ) {
                if ( ( $IndexObjectStatus{$Index}->{ObjectFails} ) ) {
                    $Self->Print("<yellow>Success with object fails.\n</yellow>");
                    $Self->Print(
                        "Failed objects count: " . $IndexObjectStatus{$Index}->{ObjectFails} . "\n"
                    );
                }
                else {
                    $Self->Print("<green>Success.\n</green>");
                }
            }
            else {
                $Self->Print("<red>Failed.\n</red>");
            }
        }
    }
    else {
        $Self->Print("\n<yellow>No data to reindex found.</yellow>\n");
    }

    return $Self->ExitCodeOk();
}

sub PostRun {
    my ( $Self, %Param ) = @_;

    my $CacheObject        = $Kernel::OM->Get('Kernel::System::Cache');
    my $PIDObject          = $Kernel::OM->Get('Kernel::System::PID');
    my $ReindexationObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Reindexation');

    return $Self->ExitCodeOk() if !$Self->{Started};

    $CacheObject->CleanUp(
        Type => 'ReindexingProcess',
    );

    $PIDObject->PIDDelete(
        Name => 'SearchEngineReindex',
    );

    for my $Index ( @{ $Self->{Index} } ) {
        my $Result = $Self->{SearchObject}->IndexRefresh(
            Index => $Index
        );
    }
    my $Success = $ReindexationObject->DataEqualitySet(
        ClusterID     => $Self->{ClusterConfig}->{ClusterID},
        Indexes       => $Self->{Index},
        NoPermissions => 1,
    );

    $Self->Print("<red>Cleaned up Cache and PID for reindexing process</red>\n");

    return $Self->ExitCodeOk();
}

1;
