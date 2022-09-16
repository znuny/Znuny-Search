# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Admin::Details;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DB',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Search',,
    'Kernel::System::Search::Object',
);

=head1 NAME

Kernel::System::Search::Admin::Details - admin details lib

=head1 DESCRIPTION

Cluster details base backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

    my $SearchAdminDetailsObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Details');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    bless( $Self, $Type );

    return $Self;
}

=head2 BuildDetailsSection()

Build details section based on default search engine
structure(Cluster, Node, Index). There is possibility to override
this function and template for specific engine.

    my $Details = $DetailsObject->BuildDetailsSection(
        ClusterConfig => $ClusterConfig,
        UserID => $UserID,
    );

=cut

sub BuildDetailsSection {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(ClusterConfig UserID)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Kernel::System::Search'],
    );

    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $EngineDiagnosis = $SearchObject->DiagnosticDataGet();

    return if !$EngineDiagnosis;

    my $StoredClusterState = $Self->ClusterStateGet(
        ClusterID    => $Param{ClusterConfig}{ClusterID},
        ClusterState => $EngineDiagnosis
    ) || {};

    if ( !IsHashRefWithData($StoredClusterState) ) {
        $Self->ClusterStateSet(
            ClusterID    => $Param{ClusterConfig}{ClusterID},
            ClusterState => $EngineDiagnosis,
            UserID       => $Param{UserID}
        );

        $StoredClusterState = $Self->ClusterStateGet(
            ClusterID    => $Param{ClusterConfig}{ClusterID},
            ClusterState => $EngineDiagnosis
        ) || {};
        return if !IsHashRefWithData($StoredClusterState);
    }

    $Self->{Engine} ||= 'ES';

    my $State = $Param{EngineClusterState};

    $State = $Self->StateCheck(
        Engine => $EngineDiagnosis,
        Store  => $StoredClusterState,
    );

    for my $Node ( sort keys %{ $State->{Nodes} } ) {
        my $NodeName = $Node;
        my $NodeData = $State->{Nodes}->{$Node};
        my $Changes  = $State->{Changes}->{Nodes}->{$Node} || {};

        $LayoutObject->Block(
            Name => 'Node',
            Data => {
                Name             => $NodeName,
                Shards           => $NodeData->{Shards},
                TransportAddress => $NodeData->{TransportAddress},
                ObjectType       => $NodeData->{ObjectType},
                IP               => $NodeData->{IP},
                Style            => $Changes,
                Changes          => IsHashRefWithData($Changes) ? 1 : 0,
            }
        );
    }

    # properties that will define integrity of index
    my %IndexIntegrityProperties = (
        Index          => 1,
        Name           => 1,
        Status         => 1,
        PrimaryShards  => 1,
        RecoveryShards => 1,
    );

    for my $Index ( sort keys %{ $State->{Indexes} } ) {
        my $IndexName = $Index;
        my $IndexData = $State->{Indexes}->{$Index};
        my $Changes   = $State->{Changes}->{Indexes}->{$Index} || {};

        my $IndexIsValid = $SearchChildObject->IndexIsValid(
            IndexName => $IndexName,
            RealName  => 1,
        );

        my $IsIntegral = 1;

        CHANGE:
        for my $Property ( sort keys %{$Changes} ) {
            if ( $IndexIntegrityProperties{$Property} ) {
                $IsIntegral = 0;
                last CHANGE;
            }
        }

        $LayoutObject->Block(
            Name => 'Index',
            Data => {
                Name           => $IndexName,
                Status         => $IndexData->{Status},
                Size           => $IndexData->{Size},
                PrimaryShards  => $IndexData->{PrimaryShards},
                RecoveryShards => $IndexData->{RecoveryShards},
                Style          => $Changes,
                IsIntegral     => $IsIntegral,
                IndexIsValid   => $IndexIsValid,
            }
        );
    }

    INDEX:
    for my $RegisteredIndex ( sort keys %{ $SearchObject->{Config}->{RegisteredIndexes} } ) {
        my $Loaded = $SearchChildObject->_LoadModule(
            Module => "Kernel::System::Search::Object::$RegisteredIndex",
            Silent => 1,
        );
        my $IndexObject;
        my $IndexName;

        # loaded index registration will show real index name
        if ($Loaded) {
            $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$RegisteredIndex");
            $IndexName   = $IndexObject->{Config}->{IndexRealName};
        }
        else {
            # not valid index registration will show registered name
            $IndexName = $RegisteredIndex;
        }

        if ( !grep { $_ eq $IndexObject->{Config}->{IndexRealName} } keys %{ $State->{Indexes} } ) {
            $LayoutObject->Block(
                Name => 'Index',
                Data => {
                    Name           => $IndexName,
                    Status         => '-',
                    Size           => '-',
                    PrimaryShards  => '-',
                    RecoveryShards => '-',
                    Style          => {
                        Index => 'Missing'
                    },
                    IsRegistered => 'Registered',
                    IndexIsValid => $Loaded,        # registration is checked so check only for valid load
                    IsIntegral   => 1,              # this block can render only when integrity has been synchronized
                }
            );
        }
    }

    # build data for cluster status details
    my %ClusterStatusDetails;
    if ( $State->{Cluster}->{Status} ) {
        %ClusterStatusDetails = %{ $State->{Cluster} };
        delete $ClusterStatusDetails{Status};

        # values of this mapping will be used as as label
        # name/title for displayed properties
        my %PropertiesMapping = (
            ClusterName                 => 'Cluster name',
            TimedOut                    => 'Timed out',
            NumberOfNodes               => 'Number of nodes',
            NumberOfDataNodes           => 'Number of data nodes',
            NumberOfPrimaryShards       => 'Number of primary shards',
            ActiveShards                => 'Active shards',
            RelocatingShards            => 'Relocating shards',
            InitializingShards          => 'Initializing shards',
            UnassignedShards            => 'Unassigned shards',
            DelayedUnassignedShards     => 'Delayed unassigned shards',
            NumberOfPendingTasks        => ' Number of pending tasks',
            NumberOfInFlightFetch       => 'Number of in flight fetch',
            TaskMaxWaitingInQueueMillis => 'Maximum waiting time for task (ms)',
            ActiveShardsPercentAsNumber => 'Active shards (%)',
        );

        # render info icon
        $LayoutObject->Block(
            Name => 'ClusterStatusDetails',
        );

        # display each property for cluster health
        for my $Property ( sort keys %PropertiesMapping ) {
            if ( defined $State->{Cluster}->{$Property} ) {
                my $Value;
                if ( !$State->{Cluster}->{$Property} ) {
                    if ( $Property ne 'TimedOut' ) {
                        $Value = 0;
                    }
                    else {
                        $Value = 'no';
                    }
                }
                else {
                    $Value = $State->{Cluster}->{$Property};
                }

                $LayoutObject->Block(
                    Name => 'ClusterStatusDetailsRow',
                    Data => {
                        Title => $PropertiesMapping{$Property},
                        Label => $PropertiesMapping{$Property},
                        Value => $Value,
                    },
                );
            }
        }
    }

    # copy variable as it will be used to
    # decide if sync is needed
    # original data will be returned afterwards
    my %StateChanges = %{ $State->{Changes} };

    # decide if synchronization is needed
    # to do so delete any change properties that are not
    # important for synchronization action
    # that is for example "Size"
    if ( IsHashRefWithData( $StateChanges{Indexes} ) ) {
        for my $IndexRealName ( sort keys %{ $StateChanges{Indexes} } ) {
            my $PropertiesCount = keys %{ $StateChanges{Indexes}->{$IndexRealName} };
            if ( $PropertiesCount == 1 ) {
                my @Value = keys %{ $StateChanges{Indexes}->{$IndexRealName} };
                if ( !$IndexIntegrityProperties{ $Value[0] } ) {
                    delete $StateChanges{Indexes}->{$IndexRealName};
                }
            }
        }
    }

    # check if sync is needed
    my $SynchronizeNeeded = IsHashRefWithData( $StateChanges{Indexes} ) || IsHashRefWithData( $StateChanges{Nodes} );

    my $DetailsHTML = $LayoutObject->Output(
        TemplateFile => "AdminSearch/$Self->{Engine}",
        Data         => {
            %{$State},
            Changes => {
                %StateChanges
            }
        },
    );

    return {
        HTML        => $DetailsHTML,
        Changes     => $State->{Changes},
        Synchronize => $SynchronizeNeeded,
    };
}

=head2 ClusterStateSet()

store cluster state data as JSON in database table

    my $Success = $DetailsObject->ClusterStateSet(
        ClusterState => $ClusterState,
        ClusterID    => $ClusterID,
    );

=cut

sub ClusterStateSet {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(ClusterID ClusterState)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    $Param{ClusterState} = $JSONObject->Encode( Data => $Param{ClusterState} );

    my $SQL
        = "INSERT INTO search_cluster_states (cluster_id, state, create_time, create_by ) VALUES (?, ?, current_timestamp, ?)";

    return if $DBObject->Do(
        SQL  => $SQL,
        Bind => [ \$Param{ClusterID}, \$Param{ClusterState}, \$Param{UserID} ],
    );

    return 1;
}

=head2 ClusterStateGet()

receive cluster state data as JSON from database table

    my $ClusterState = $DetailsObject->ClusterStateGet(
        ClusterID    => $ClusterID,
    );

=cut

sub ClusterStateGet {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(ClusterID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $SQL = "SELECT * FROM search_cluster_states WHERE cluster_id = ? ORDER BY create_time ASC";

    $DBObject->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{ClusterID} ],
        LIMIT => 1,
    );

    my %ClusterStateRow;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ClusterStateRow{StateID}      = $Row[0];
        $ClusterStateRow{ClusterID}    = $Row[1];
        $ClusterStateRow{ClusterState} = $JSONObject->Decode( Data => $Row[2] );
        $ClusterStateRow{CreateBy}     = $Row[3];
        $ClusterStateRow{CreateTime}   = $Row[4];
    }

    return \%ClusterStateRow;
}

=head2 StateCheck()

check differences between engine and stored state of cluster details

    my $State = $DetailsObject->StateCheck(
        Engine => $EngineData,
        Store  => $StoreData,
    );

=cut

sub StateCheck {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Engine Store)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $EngineState = $Param{Engine};
    my $StoreState  = $Param{Store}{ClusterState};

    my %State;
    for my $StoreClusterColumn ( sort keys %{ $StoreState->{Cluster} } ) {
        $State{Cluster}{$StoreClusterColumn} = $EngineState->{Cluster}->{$StoreClusterColumn} || '';
        if ( $StoreState->{Cluster}->{$StoreClusterColumn} ne $EngineState->{Cluster}->{$StoreClusterColumn} ) {
            $State{Changes}{Cluster}{$StoreClusterColumn} = 'Change';
        }
    }

    TYPE:
    for my $Type (qw(Indexes Nodes)) {
        INDEX:
        for my $Index ( sort keys %{ $StoreState->{$Type} } ) {
            if ( !$EngineState->{$Type}->{$Index} ) {
                $State{$Type}{$Index} = $StoreState->{$Type}->{$Index} || {};
                $State{Changes}{$Type}{$Index}{Index} = 'Removed';
                next INDEX;
            }
            ATTRIBUTE:
            for my $IndexAttributes ( sort keys %{ $StoreState->{$Type}->{$Index} } ) {
                $StoreState->{$Type}->{$Index}->{$IndexAttributes}  //= '';
                $EngineState->{$Type}->{$Index}->{$IndexAttributes} //= '';

                $State{$Type}{$Index}{$IndexAttributes} = $EngineState->{$Type}->{$Index}->{$IndexAttributes};

                if (
                    $StoreState->{$Type}->{$Index}->{$IndexAttributes} ne
                    $EngineState->{$Type}->{$Index}->{$IndexAttributes}
                    )
                {
                    $State{Changes}{$Type}{$Index}{$IndexAttributes} = 'Change';
                    next ATTRIBUTE;
                }
            }
        }

        for my $EngineClusterColumn ( sort keys %{ $EngineState->{$Type} } ) {
            if ( !grep { $_ eq $EngineClusterColumn } keys %{ $State{$Type} } ) {
                $State{$Type}{$EngineClusterColumn} = $EngineState->{$Type}->{$EngineClusterColumn};
                $State{Changes}{$Type}{$EngineClusterColumn}{Index} = 'Added';
            }
        }
    }

    return \%State;
}

1;
