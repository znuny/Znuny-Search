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

    my $DetailsObject = $DetailsObject->BuildDetailsSection(
        ClusterConfig => $ClusterConfig,
        UserID => $UserID,
    );

=cut

sub BuildDetailsSection {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->ObjectsDiscard(
        Objects => ['Kernel::System::Search'],
    );

    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
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

    for my $Index ( sort keys %{ $State->{Indexes} } ) {
        my $IndexName = $Index;
        my $IndexData = $State->{Indexes}->{$Index};
        my $Changes   = $State->{Changes}->{Indexes}->{$Index} || {};

        my $IndexIsValid = $SearchChildObject->RealIndexIsValid(
            IndexRealName => $IndexName,
        );

        $LayoutObject->Block(
            Name => 'Index',
            Data => {
                Name           => $IndexName,
                Status         => $IndexData->{Status},
                Size           => $IndexData->{Size},
                PrimaryShards  => $IndexData->{PrimaryShards},
                RecoveryShards => $IndexData->{RecoveryShards},
                Style          => $Changes,
                Changes        => IsHashRefWithData($Changes) ? 1 : 0,
                IndexIsValid   => $IndexIsValid,
            }
        );
    }

    INDEX:
    for my $RegisteredIndex ( @{ $SearchObject->{Config}->{RegisteredIndexes} } ) {
        my $Loaded = $SearchChildObject->_LoadModule(
            Module => "Kernel::System::Search::Object::$RegisteredIndex",
            Silent => 1
        );
        next INDEX if !$Loaded;
        my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$RegisteredIndex");
        if ( !grep { $_ eq $IndexObject->{Config}->{IndexRealName} } keys %{ $State->{Indexes} } ) {
            $LayoutObject->Block(
                Name => 'Index',
                Data => {
                    Name           => $IndexObject->{Config}->{IndexRealName},
                    Status         => '-',
                    Size           => '-',
                    PrimaryShards  => '-',
                    RecoveryShards => '-',
                    Style          => {
                        Index => 'Missing'
                    },
                    IsRegistered => 'Registered'
                }
            );
        }
    }

    my $DetailsHTML = $LayoutObject->Output(
        TemplateFile => "AdminSearch/$Self->{Engine}",
        Data         => {
            %{$State},
        },
    );

    my $Changes;
    $Changes = 1 if IsHashRefWithData( $State->{Changes}->{Indexes} ) ||
        IsHashRefWithData( $State->{Changes}->{Nodes} );

    return {
        HTML    => $DetailsHTML,
        Changes => $Changes
    };
}

=head2 ClusterStateSet()

store cluster state data as JSON in database table

    my $DetailsObject = $DetailsObject->ClusterStateSet(
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

    my $DetailsObject = $DetailsObject->ClusterStateGet(
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

    my $DetailsObject = $DetailsObject->StateCheck(
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
