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
    $Self->AddOption(
        Name => 'sync',
        Description =>
            "Fully synchronize data between SQL and custom search engine.",
        Required => 0,
        HasValue => 0,
        Multiple => 0,
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

    $Self->{Synchronize} = $Self->GetOption('sync');
    $Self->{PIDName}     = $Self->{Synchronize} ? 'SearchEngineReindex' : 'SearchEngineSync';

    my $FullReindexation = !$StartFrom && !$Limit;

    if ( $Self->{Synchronize} && ( defined $StartFrom || $Limit || $Recreate ) ) {
        $Self->Print(
            "<red>Parameter 'sync' cannot be used in combination with 'start-from', 'limit' or 'recreate'!</red>\n"
        );
        return $Self->ExitCodeError();
    }

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
        Name => $Self->{PIDName},
    );

    if ( IsHashRefWithData( $Self->{ReindexingProcess} ) ) {
        if ( $Self->{Synchronize} ) {
            $Self->Print("<yellow>There is already a locked synchronizing process\n</yellow>");
        }
        else {
            $Self->Print("<yellow>There is already a locked re-indexing process\n</yellow>");
        }

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

    my $DataEqualityResponse = $ReindexationObject->DataEqualitySet(
        ClusterID       => $Self->{ClusterConfig}->{ClusterID},
        Indexes         => $Self->{Index},
        NoPermissions   => 1,
        GetEqualityData => $Self->{Synchronize} ? 1 : 0,
    );

    my $EqualityDataStatus;
    my %IndexObjectStatus;
    my @Objects;
    if ( IsArrayRefWithData( $Self->{Index} ) ) {
        my $Counter = 0;

        INDEX:
        for my $Index ( @{ $Self->{Index} } ) {

            my $DataEquality = $ReindexationObject->DataEqualityGet(
                ClusterID => $Self->{ClusterConfig}->{ClusterID},
                IndexName => $Index,
            );

            $EqualityDataStatus->{$Index} = $DataEquality->{$Index};

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
        Name  => $Self->{PIDName},
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
    ) if !$Self->{Synchronize};

    $Self->{SearchObject}->ClusterInit(
        Force => $ClusterReinitialize,
    );

    # list all indexes on remote (engine) side
    my @ActiveClusterRemoteIndexList = $Self->{SearchObject}->IndexList();
    my $ReindexationSettings         = $ConfigObject->Get('SearchEngine::Reindexation')->{Settings};

    my $ReindexationStep = $ReindexationSettings->{ReindexationStep} // 10;

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
        ) if !$Self->{Synchronize};

        $CacheObject->Set(
            Type  => 'ReindexingProcess',
            Key   => 'ReindexedIndex',
            Value => $IndexName,
            TTL   => 24 * 60 * 60,
        ) if !$Self->{Synchronize};

        my $IndexCreated;

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

            $IndexCreated = 1;
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

            $IndexCreated = 1;
        }

        if ($IndexCreated) {

            # initialize index
            my $InitSuccess = $Self->{SearchObject}->IndexInit(
                Index => $IndexName,
            );

            if ( !$InitSuccess ) {
                $Self->PrintError("Can't initialize index $IndexName!\n");
                $IndexObjectStatus{$IndexName}->{Successful} = 0;
                next OBJECT;
            }

            $Self->Print("<green>Index initialized.</green>\n");
        }

        my $LastObjectID = $StartFrom ? [$StartFrom] : $SearchIndexObject->ObjectListIDs(
            OrderBy => 'DESC',
            Limit   => 1
        );

        my $Identifier = $SearchIndexObject->{Config}->{Identifier};

        if ( !( IsArrayRefWithData($LastObjectID) ) ) {
            $Self->PrintError(
                "Couldn't find last object id.\n\n"
            );
            $IndexObjectStatus{$IndexName}->{Successful} = 0;
            next OBJECT;
        }

        if ( $Self->{Synchronize} ) {
            $Self->Print("<yellow>Synchronizing index data..</yellow>\n\n");

            my $DBEngineDataCount        = $DataEqualityResponse->{$IndexName}->{DBEngine}->{Count}     // 0;
            my $CustomEngineDataCount    = $DataEqualityResponse->{$IndexName}->{CustomEngine}->{Count} // 0;
            my $EqualityPercentageStatus = $DataEqualityResponse->{$IndexName}->{EqualityPercentage}    // 0;

            $Self->Print(
                "<yellow>Already indexed data:\nStatus: $EqualityPercentageStatus%.\n" .
                    "Objects count on custom engine side: $CustomEngineDataCount\n" .
                    "Objects count on sql engine side: $DBEngineDataCount\n</yellow>"
            );

            my $FirstSQLObjectID = $SearchIndexObject->ObjectListIDs(
                OrderBy => 'Up',
                Limit   => 1
            );

            my $FirstCustomEngineObjectID = $Self->{SearchObject}->Search(
                Objects       => [$IndexName],
                QueryParams   => {},
                Limit         => 1,
                SortBy        => [$Identifier],
                ResultType    => 'ARRAY_SIMPLE',
                OrderBy       => ['Up'],
                Fields        => [ [ $IndexName . '_' . $Identifier ] ],
                NoPermissions => 1,
            );

            my $LastCustomEngineObjectID = $Self->{SearchObject}->Search(
                Objects       => [$IndexName],
                QueryParams   => {},
                Limit         => 1,
                SortBy        => [$Identifier],
                ResultType    => 'ARRAY_SIMPLE',
                OrderBy       => ['Down'],
                Fields        => [ [ $IndexName . '_' . $Identifier ] ],
                NoPermissions => 1,
            );

            my %ObjectIDs = (
                SQL => {
                    First => $FirstSQLObjectID->[0] // 1,
                    Last  => $LastObjectID->[0]     // 1,
                },
                SearchEngine => {
                    First => $FirstCustomEngineObjectID->{$IndexName}->[0] // 1,
                    Last  => $LastCustomEngineObjectID->{$IndexName}->[0]  // 1,
                }
            );

            my %SearchRange = (
                From => $ObjectIDs{SearchEngine}->{First} < $ObjectIDs{SQL}->{First}
                ?
                    $ObjectIDs{SearchEngine}->{First}
                : $ObjectIDs{SQL}->{First},
                To => $ObjectIDs{SearchEngine}->{Last} > $ObjectIDs{SQL}->{Last}
                ?
                    $ObjectIDs{SearchEngine}->{Last}
                : $ObjectIDs{SQL}->{Last},
            );

            my $StartID = $SearchRange{From};
            my $EndID   = $SearchRange{To};

            if ( !IsPositiveInteger($StartID) || !IsPositiveInteger($EndID) || $StartID > $EndID ) {
                $Self->PrintError('Could not determine a valid synchronization data set!');
                $IndexObjectStatus{$IndexName}->{Successful} = 0;
                next OBJECT;
            }

            my %Actions;
            my @IDsToCheckUpdateTime;

            my $ChangeTimeColumnName = $SearchIndexObject->{Config}->{ChangeTimeColumnName};

            if ( !$ChangeTimeColumnName ) {
                $Self->PrintError(
                    'Specified index to synchronize does not contain column name set' .
                        "in it's module config. " .
                        'Synchronization will continue, but entries will be only added' . "\n" .
                        'or delete if needed - existing entries in both engines can\'t be compared.'
                );
            }
            else {
                $Self->PrintError(
                    "Specified index to synchronize does not contain $ChangeTimeColumnName column, so it is not possible\n"
                        .
                        'to identify what entries needs to be updated. Synchronization will continue, but entries will be only added'
                        . "\n"
                        .
                        'or delete if needed - existing entries in both engines can\'t be compared.'
                    )
                    if !$SearchIndexObject->{Fields}->{$ChangeTimeColumnName}
                    && !$SearchIndexObject->{ExternalFields}->{$ChangeTimeColumnName};
            }

            $Self->Print(
                "<yellow>Searching both engines for objects from id: $StartID to: $EndID</yellow>\n"
            );

            SEARCH:
            for ( my $i = $StartID; $i <= $EndID; $i += 10000 ) {
                my %SearchParams = (
                    Objects     => [$IndexName],
                    QueryParams => {
                        $Identifier => [ $i .. $i + 9999 ],
                    },
                    Limit         => 10000,
                    ResultType    => 'HASH',
                    Fields        => [ [ $IndexName . '_' . $Identifier, $IndexName . '_' . $ChangeTimeColumnName ] ],
                    NoPermissions => 1,
                );

                my $SQLSearch = $Self->{SearchObject}->Search(
                    %SearchParams,
                    UseSQLSearch        => 1,
                    Force               => 1,    # search in objects that have blocked fallback
                    IgnoreDynamicFields => 1,    # Ticket/CustomerUser index compatibility
                    IgnoreArticles      => 1,    # Ticket index compatibility
                );

                my $CustomEngineSearch = $Self->{SearchObject}->Search(
                    %SearchParams,
                );

                my %SQLData = IsHashRefWithData( $SQLSearch->{$IndexName} ) ? %{ $SQLSearch->{$IndexName} } : ();
                my %CustomSearchEngineData = IsHashRefWithData( $CustomEngineSearch->{$IndexName} )
                    ? %{ $CustomEngineSearch->{$IndexName} }
                    : ();

                SQL_DATA:
                for my $ID ( reverse sort keys %SQLData ) {

                    # entry does not exists in custom search engine
                    # but exists in sql db
                    if ( !defined $CustomSearchEngineData{$ID} ) {
                        push @{ $Actions{ObjectIndexAdd} }, $ID;
                    }
                    else {
                        # entry exists in both engines
                        # check it's update time and update if needed
                        # IMPORTANT! If custom engine update time anyhow differs from
                        # sql db, entry will be updated on engine side
                        if (
                            $SQLData{$ID}->{$ChangeTimeColumnName}
                            && $CustomSearchEngineData{$ID}->{$ChangeTimeColumnName}
                            )
                        {
                            my $SQLChangeTimeObject = $Kernel::OM->Create(
                                'Kernel::System::DateTime',
                                ObjectParams => {
                                    String => $SQLData{$ID}->{$ChangeTimeColumnName},
                                }
                            );
                            my $SearchEngineChangeTimeObject = $Kernel::OM->Create(
                                'Kernel::System::DateTime',
                                ObjectParams => {
                                    String => $CustomSearchEngineData{$ID}->{$ChangeTimeColumnName},
                                }
                            );
                            if ( !$SQLChangeTimeObject && !$SearchEngineChangeTimeObject ) {
                                $Self->PrintError(
                                    "Could not build correct DateTime object from '$ChangeTimeColumnName' column for object id: $ID",
                                );
                                next SQL_DATA;
                            }
                            else {
                                my $Result
                                    = $SQLChangeTimeObject->Compare( DateTimeObject => $SearchEngineChangeTimeObject );
                                my $ChangeTimeIsDifferent = $Result eq 1 || $Result eq -1;

                                if ($ChangeTimeIsDifferent) {
                                    push @{ $Actions{ObjectIndexUpdate} }, $ID;
                                }
                            }
                        }
                    }
                }

                for my $ID ( reverse sort keys %CustomSearchEngineData ) {

                    # entry exists in custom search engine
                    # but does not exists in the SQL db
                    if ( !defined $SQLData{$ID} ) {
                        push @{ $Actions{ObjectIndexRemove} }, $ID;
                    }
                }
            }

            # perform synchronization based on queue of accumulated data
            ACTION:
            for my $Action (qw(ObjectIndexAdd ObjectIndexUpdate ObjectIndexRemove)) {
                my $IDsToProcess = $Actions{$Action};
                next ACTION if !IsArrayRefWithData($IDsToProcess);
                my $IDsToProcessCount = scalar @{$IDsToProcess};

                # order of synchronization is the same as reindexation - start from the end
                # perform synchronization in part of requests
                for ( my $i = 0; $i < $IDsToProcessCount; $i += $ReindexationStep ) {
                    my $ArrayEndIndex = $i + $ReindexationStep > $IDsToProcessCount
                        ? $IDsToProcessCount - 1
                        : $i + $ReindexationStep - 1;
                    my @IDsPart = @{$IDsToProcess}[ $i .. $ArrayEndIndex ];

                    my $Result = $Self->{SearchObject}->$Action(
                        Index         => $IndexName,
                        Refresh       => 0,
                        ObjectID      => \@IDsPart,
                        NoPermissions => 1,
                    );

                    my $IDsPartCount = scalar @IDsPart;

                    if ( !$Result ) {
                        $IndexObjectStatus{$IndexName}->{SyncObjectsStatus}->{$Action}->{Failed}->{Count}
                            += $IDsPartCount;
                        $IndexObjectStatus{$IndexName}->{ObjectFailsCount} += $IDsPartCount;
                    }
                    else {
                        $IndexObjectStatus{$IndexName}->{SyncObjectsStatus}->{$Action}->{Success}->{Count}
                            += $IDsPartCount;
                    }
                }
            }

            $IndexObjectStatus{$IndexName}->{Successful} = 1;
            if ( $IndexObjectStatus{$IndexName} && $IndexObjectStatus{$IndexName}->{SyncObjectsStatus} ) {
                $Self->Print("<green>Done.</green>\n\n");
            }
        }
        else {
            $Self->Print("<yellow>Adding index data..</yellow>\n");

            my $SQLObjectCount = $SearchIndexObject->ObjectListIDs(
                ResultType => 'COUNT',
            );

            if ( !($SQLObjectCount) ) {
                $Self->Print(
                    "<yellow>No data to re-index.</yellow>\n\n"
                );
                $Self->Print("<green>Done.</green>\n");
                $IndexObjectStatus{$IndexName}->{Successful} = 1;
                next OBJECT;
            }

            my $GeneralStartTime = Time::HiRes::time();

            my $From;
            my $Refresh = 0;
            my $Processed;
            my $EndID;

            if ($StartFrom) {
                $EndID = defined $Limit ? $LastObjectID->[0] - $Limit : 1;
            }
            else {
                $EndID = defined $Limit ? $LastObjectID->[0] - $Limit : 1;
            }

            my $StartID = $LastObjectID->[0];
            $EndID++ if ( defined $Limit );
            $EndID = 1 if ( $EndID < 1 );

            my $ReindexationRange = $ReindexationStep > $StartID - $EndID ? $StartID - $EndID + 1 : $ReindexationStep;

            my $TotalCount = $SearchIndexObject->ObjectListIDs(
                QueryParams => {
                    $Identifier => {
                        Operator => 'BETWEEN',
                        Value    => {
                            From => $EndID,
                            To   => $StartID,
                        },
                    },
                },
                ResultType => 'COUNT',
            );

            if ($TotalCount) {
                STEP:
                for ( my $i = $StartID; $i >= $EndID; $i = $i - $ReindexationRange ) {

                    my $From = $i;
                    my $To   = $i - $ReindexationRange + 1;

                    if ( $To < $EndID ) {
                        $To = $EndID;
                    }

                    $To = 1 if ( $To < 1 );

                    my @ArrayPiece;
                    for ( my $j = $From; $j >= $To; $j-- ) {
                        push @ArrayPiece, $j;
                    }

                    my $ObjectIDs = $SearchIndexObject->ObjectListIDs(
                        QueryParams => {
                            $Identifier => {
                                Operator => 'BETWEEN',
                                Value    => {
                                    From => $ArrayPiece[-1],
                                    To   => $ArrayPiece[0],
                                },
                            },
                        },
                    );

                    next STEP if !IsArrayRefWithData($ObjectIDs);

                    my $Result = $Self->{SearchObject}->ObjectIndexAdd(
                        Index    => $IndexName,
                        ObjectID => $ObjectIDs,
                        Refresh  => 0,
                        Reindex  => 1,
                    );

                    my $ObjectIDCount = scalar @{$ObjectIDs};
                    $Processed += $ObjectIDCount;

                    my $Percent = int( $Processed / ( $TotalCount / 100 ) );

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
                            "<yellow>$Processed</yellow> of <yellow>$TotalCount</yellow> processed (<yellow>$Percent %</yellow> done).\n"
                        );
                    }

                    $CacheObject->Set(
                        Type  => 'ReindexingProcess',
                        Key   => 'Percentage',
                        Value => $Percent,
                        TTL   => 24 * 60 * 60,
                    );

                    $IndexObjectStatus{$IndexName}->{ObjectFailsCount} += $ObjectIDCount if !defined $Result;
                }
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
    }

    $Self->Print("\n<yellow>Summary:</yellow>\n");
    if ( keys %IndexObjectStatus ) {
        OBJECT:
        for my $Index ( sort keys %IndexObjectStatus ) {
            $Self->Print("\n<yellow>Index: $Index</yellow>\n");

            $Self->Print("<yellow>Status:</yellow> ");
            if ( $IndexObjectStatus{$Index}->{Successful} ) {
                if ( $Self->{Synchronize} ) {
                    if ( !$IndexObjectStatus{$Index}->{SyncObjectsStatus} ) {
                        $Self->Print("\n<yellow>No data to synchronize found.</yellow>\n");
                    }

                    if ( ( $IndexObjectStatus{$Index}->{SyncObjectsStatus} ) ) {
                        my %ActionOutputMapping = (
                            ObjectIndexAdd    => 'Added',
                            ObjectIndexUpdate => 'Updated',
                            ObjectIndexRemove => 'Removed',
                        );

                        my %StatusOutputMapping = (
                            Failed  => 'failed',
                            Success => 'success',
                        );

                        my %StatusColorOutputMapping = (
                            Failed  => 'red',
                            Success => 'yellow',
                        );

                        $Self->Print("\n\n");
                        for my $Status (qw (Success Failed)) {
                            for my $Action (qw (ObjectIndexAdd ObjectIndexUpdate ObjectIndexRemove)) {
                                my $Count
                                    = $IndexObjectStatus{$Index}->{SyncObjectsStatus}->{$Action}->{$Status}->{Count}
                                    || 0;
                                my $Color = $Count ? $StatusColorOutputMapping{$Status} : 'yellow';

                                $Self->Print(
                                    "$ActionOutputMapping{$Action} objects count ($StatusOutputMapping{$Status}):" .
                                        " <$Color> $Count </$Color>\n"
                                );
                            }
                        }
                    }
                }
                if ( ( $IndexObjectStatus{$Index}->{ObjectFailsCount} ) ) {
                    $Self->Print("<yellow>Success with object fails.\n</yellow>");
                    $Self->Print(
                        "Failed objects count: " . $IndexObjectStatus{$Index}->{ObjectFailsCount} . "\n"
                    );
                }
                else {
                    $Self->Print("<green>Success.\n</green>");
                    push @{ $Self->{FullySuccesfullReindexatedObjects} }, $Index if $FullReindexation;
                }
            }
            else {
                $Self->Print("<red>Failed.\n</red>");
            }
        }
    }
    else {
        if ( $Self->{Synchronize} ) {
            $Self->Print("\n<yellow>No data to synchronize found.</yellow>\n");
        }
        else {
            $Self->Print("\n<yellow>No data to reindex found.</yellow>\n");
        }
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
    ) if !$Self->{Synchronize};

    $PIDObject->PIDDelete(
        Name => $Self->{PIDName},
    );

    for my $Index ( @{ $Self->{Index} } ) {
        my $Result = $Self->{SearchObject}->IndexRefresh(
            Index => $Index
        );
    }

    my $Success = $ReindexationObject->DataEqualitySet(
        ClusterID                        => $Self->{ClusterConfig}->{ClusterID},
        Indexes                          => $Self->{Index},
        UpdateReindexationTimeForIndexes => $Self->{FullySuccesfullReindexatedObjects},
        NoPermissions                    => 1,
    );

    if ( !$Self->{Synchronize} ) {
        $Self->Print("<green>Cleaned up Cache and PID for reindexing process</green>\n");
    }
    else {
        $Self->Print("<green>Cleaned up PID for synchronizing process</green>\n");
    }

    return $Self->ExitCodeOk();
}

1;
