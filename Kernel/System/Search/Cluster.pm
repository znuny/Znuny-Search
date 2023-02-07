# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Cluster;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::DB',
    'Kernel::System::Valid',
    'Kernel::System::JSON',
    'Kernel::System::Search::Object',
    'Kernel::System::YAML',
);

=head1 NAME

Kernel::System::Search::Cluster - search cluster lib

=head1 DESCRIPTION

All search cluster related functions.

=head1 PUBLIC INTERFACE

=head2 new()

my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 ClusterList()

get list of all registered clusters

    my $ClusterList = $ClusterObject->ClusterList();

=cut

sub ClusterList {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name FROM search_clusters',
    );

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $Data{ $Data[0] } = $Data[1];
    }

    return \%Data;
}

=head2 ClusterGet()

get data of specified cluster

    my $Cluster = $ClusterObject->ClusterGet(
        ClusterID => $ClusterID
    );

=cut

sub ClusterGet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    NEEDED:
    for my $Needed (qw(ClusterID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, engine, valid_id, create_time, change_time, description '
            . 'FROM search_clusters WHERE id = ?',
        Bind  => [ \$Param{ClusterID} ],
        Limit => 1,
    );

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ClusterID   => $Data[0],
            Name        => $Data[1],
            EngineID    => $Data[2],
            ValidID     => $Data[3],
            CreateTime  => $Data[4],
            ChangeTime  => $Data[5],
            Description => $Data[6],
        );
    }

    return \%Data;
}

=head2 ClusterAdd()

add cluster

    my $Success = $ClusterObject->ClusterAdd(
        Name => $Name,
        ValidID => $ValidID,
        EngineID => $EngineID,
        UserID => $UserID,
    );

=cut

sub ClusterAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    NEEDED:
    for my $Needed (qw(Name ValidID EngineID UserID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    return if $Self->NameExistsCheck(
        Name => $Param{Name},
    );

    $Param{Description} ||= '';

    return if !$DBObject->Do(
        SQL =>
            'INSERT INTO search_clusters (name, valid_id, description, engine,'
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name},     \$Param{ValidID}, \$Param{Description},
            \$Param{EngineID}, \$Param{UserID},  \$Param{UserID},
        ],
    );

    return 1;
}

=head2 ClusterDelete()

remove cluster

    my $Success = $ClusterObject->ClusterDelete(
        ClusterID => $ClusterID
    );

=cut

sub ClusterDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    NEEDED:
    for my $Needed (qw(ClusterID UserID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    # delete all cluster nodes
    my $ClusterNodesList = $Self->ClusterCommunicationNodeList(
        ClusterID => $Param{ClusterID}
    );

    if ( IsArrayRefWithData($ClusterNodesList) ) {
        for my $ClusterNode ( @{$ClusterNodesList} ) {
            my $Result = $Self->ClusterCommunicationNodeRemove(
                NodeID => $ClusterNode->{NodeID}
            );
            if ( !$Result ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Error while deleting cluster node!"
                );
                return;
            }
        }
    }

    $Param{Description} ||= '';

    return if !$DBObject->Do(
        SQL  => 'DELETE FROM search_clusters WHERE id = ?',
        Bind => [ \$Param{ClusterID} ],
    );

    return 1;
}

=head2 ClusterUpdate()

update cluster

    my $Success = $ClusterObject->ClusterUpdate(
        ClusterID => $ClusterID,
        %ClusterData,
    );

=cut

sub ClusterUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    NEEDED:
    for my $Needed (qw(ClusterID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my %FieldMapping = (
        ValidID     => 'valid_id',
        Description => 'description',
        Name        => 'name',
        EngineID    => 'engine'
    );

    return if $Self->NameExistsCheck(
        ID   => $Param{ClusterID},
        Name => $Param{Name},
    );

    my %Attributes;
    ATTRIBUTE:
    for my $Attribute (qw(ValidID Description Name EngineID)) {
        if ( $Param{$Attribute} ) {
            $Attributes{ $FieldMapping{$Attribute} . " = ?" } = $Param{$Attribute};
        }
    }

    my $BindQuery = join( ', ', sort keys %Attributes );

    my @AttributeValues;
    for my $Attribute ( sort keys %Attributes ) {
        push @AttributeValues, \"$Attributes{$Attribute}";
    }

    push @AttributeValues, \$Param{ClusterID};

    return if !$DBObject->Do(
        SQL  => 'UPDATE search_clusters SET ' . $BindQuery . ' WHERE id = ?',
        Bind => \@AttributeValues,
    );

    return 1;
}

=head2 ActiveClusterGet()

receive data of first valid (active) clusters

    my $ActiveCluster = $ClusterObject->ActiveClusterGet();

=cut

sub ActiveClusterGet {
    my ( $Self, %Param ) = @_;

    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, engine, valid_id, create_time, change_time, description, cluster_initialized '
            . 'FROM search_clusters WHERE valid_id IN (' . join ', ', $ValidObject->ValidIDsGet() . ') LIMIT 1',
    );

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ClusterID          => $Data[0],
            Name               => $Data[1],
            Engine             => $Data[2],
            ValidID            => $Data[3],
            CreateTime         => $Data[4],
            ChangeTime         => $Data[5],
            Description        => $Data[6],
            ClusterInitialized => $Data[7]
        );
    }

    return \%Data;
}

=head2 ClusterCommunicationNodeAdd()

store cluster communication node data in database table

    my $Result = $ClusterObject->ClusterCommunicationNodeAdd(
        Name      => $Name,
        Protocol  => $Protocol,
        ValidID   => $ValidID,
        Comment   => $Comment,
        Host      => $Host,
        Port      => $Port,
        Path      => $Path,
        Login     => $Login,
        Password  => $Password,
        ClusterID => $ClusterID,
        UserID    => $UserID,
    );

=cut

sub ClusterCommunicationNodeAdd {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Protocol Host Port ClusterID UserID Name ValidID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    # Check that the other nodes do not have the same settings
    my $CommunicationNodeList = $Self->ClusterCommunicationNodeList(
        ClusterID => $Param{ClusterID}
    );

    my $NodeNameExists = $Self->NodeNameExistsCheck(
        Name      => $Param{Name},
        ClusterID => $Param{ClusterID},
    );
    if ($NodeNameExists) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Can't add two nodes with the same names!",
        );
        return;
    }

    my $Password = '';

    my $SQL
        = "INSERT INTO search_cluster_nodes (protocol, name, valid_id, node_comment, host, port, node_path, node_login, node_password, cluster_id, create_time, create_by ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?)";

    my $Success = $DBObject->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Protocol}, \$Param{Name}, \$Param{ValidID}, \$Param{Comment}, \$Param{Host}, \$Param{Port},
            \$Param{Path},
            \$Param{Login}, \$Password, \$Param{ClusterID}, \$Param{UserID}
        ],
    );

    return if !$Success;

    $SQL = "SELECT id from search_cluster_nodes WHERE cluster_id = ? AND name = ?";

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [
            \$Param{ClusterID}, \$Param{Name}
        ],
        Limit => 1,
    );

    my @Data = $DBObject->FetchrowArray();
    my $ID   = $Data[0];

    if ( $Param{Login} && $Param{Password} ) {
        $Self->ClusterCommunicationNodeSetPassword(
            %Param,
            NodeID => $ID,
            Action => "Add",
        );
    }

    return $ID;
}

=head2 ClusterCommunicationNodeUpdate()

updates cluster communication node data in database table

    my $Result = $ClusterObject->ClusterCommunicationNodeUpdate(
        Name      => 'some-name',
        ValidID   => 1, # possible "2", "1", "0"
        Comment   => 'some-comment',
        Protocol  => $Protocol,
        Host      => $Host,
        Port      => $Port,
        Path      => $Path,
        Login     => $Login,
        Password  => $Password,
        ClusterID => $ClusterID,
        NodeID    => $NodeID,
        UserID    => 1,
        PasswordClear => 0, # optional, possible: "1", "0"
    );

=cut

sub ClusterCommunicationNodeUpdate {
    my ( $Self, %Param ) = @_;

    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Protocol Host Port ClusterID NodeID UserID Name)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $CommunicationNode = $Self->ClusterCommunicationNodeGet(
        NodeID => $Param{NodeID}
    );

    if ( !IsHashRefWithData($CommunicationNode) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Node with id: $Param{NodeID} does not exists in database.",
        );
        return;
    }

    my $CommunicationNodeList = $Self->ClusterCommunicationNodeList(
        ClusterID => $Param{ClusterID}
    );

    my $SQL
        = "UPDATE search_cluster_nodes SET name = ?, valid_id = ?, node_comment = ?, protocol = ?, host = ?, port = ?, node_path = ?, node_login = ?, cluster_id = ?, create_by = ? WHERE id = ?";

    my $Success = $DBObject->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Comment}, \$Param{Protocol}, \$Param{Host}, \$Param{Port},
            \$Param{Path},
            \$Param{Login}, \$Param{ClusterID}, \$Param{UserID}, \$Param{NodeID}
        ],
    );

    return if !$Success;

    if ( ( $Param{Login} && $Param{Password} ) || $Param{PasswordClear} ) {
        $Self->ClusterCommunicationNodeSetPassword(
            %Param,
            NodeID        => $Param{NodeID},
            Action        => "Update",
            PasswordClear => $Param{PasswordClear},
        );
    }

    return $Success;
}

=head2 ClusterCommunicationNodeRemove()

remove cluster communication node data from database table

    my $Result = $ClusterObject->ClusterCommunicationNodeRemove(
        NodeID => $NodeID
    );

=cut

sub ClusterCommunicationNodeRemove {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw( NodeID )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    # Check if node with given ID exist
    my $CommunicationNode = $Self->ClusterCommunicationNodeGet(
        NodeID => $Param{NodeID}
    );

    if ( !IsHashRefWithData($CommunicationNode) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "No node with given id: $Param{NodeID}",
        );
    }

    my $SQL = "DELETE FROM search_cluster_nodes WHERE id=?";

    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => [ \$Param{NodeID} ],
    );

    return 1;
}

=head2 ClusterCommunicationNodeList()

returns list of cluster communication nodes stored data in database table

    my $ClusterCommunicationNodeList = $ClusterObject->ClusterCommunicationNodeList(
        ClusterID => $ClusterID,
        Valid     => 1, # possible: 1,0
    );

=cut

sub ClusterCommunicationNodeList {
    my ( $Self, %Param ) = @_;

    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

    if ( !$Param{ClusterID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param ClusterID",
        );
        return;
    }

    my @CommunicationNodes;
    if ( $Param{Valid} && $Param{Valid} eq 1 ) {
        my %List = $ValidObject->ValidList();

        my ($ValidID) = grep { $List{$_} eq 'valid' } keys %List;

        return if !$DBObject->Prepare(
            SQL =>
                'SELECT id, name, valid_id, node_comment, protocol, host, port, node_path, node_login, node_password, cluster_id '
                . 'FROM search_cluster_nodes WHERE cluster_id = ? and valid_id = ?',
            Bind => [ \$Param{ClusterID}, \$ValidID ]
        );

        while ( my @Data = $DBObject->FetchrowArray() ) {
            my %Data = (
                NodeID    => $Data[0],
                Name      => $Data[1],
                ValidID   => $Data[2],
                Comment   => $Data[3],
                Protocol  => $Data[4],
                Host      => $Data[5],
                Port      => $Data[6],
                Path      => $Data[7],
                Login     => $Data[8],
                Password  => $Data[9],
                ClusterID => $Data[10]
            );
            push @CommunicationNodes, \%Data;
        }

        return \@CommunicationNodes;
    }

    return if !$DBObject->Prepare(
        SQL =>
            'SELECT id, name, valid_id, node_comment, protocol, host, port, node_path, node_login, node_password, cluster_id '
            . 'FROM search_cluster_nodes WHERE cluster_id = ?',
        Bind => [ \$Param{ClusterID} ]
    );

    while ( my @Data = $DBObject->FetchrowArray() ) {
        my %Data = (
            NodeID    => $Data[0],
            Name      => $Data[1],
            ValidID   => $Data[2],
            Comment   => $Data[3],
            Protocol  => $Data[4],
            Host      => $Data[5],
            Port      => $Data[6],
            Path      => $Data[7],
            Login     => $Data[8],
            Password  => $Data[9],
            ClusterID => $Data[10]
        );
        push @CommunicationNodes, \%Data;
    }

    return \@CommunicationNodes;
}

=head2 ClusterCommunicationNodeGet()

returns cluster communication node data stored in database table

    my $ClusterCommunicationNode = $ClusterObject->ClusterCommunicationNodeGet(
        NodeID => $NodeID, # optional
        # or
        ClusterID => $ClusterID,
        Name      => $Name,
    );

=cut

sub ClusterCommunicationNodeGet {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{NodeID} ) {
        if ( !$Param{Name} || !$Param{ClusterID} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Missing params Name and/or ClusterID!",
            );
            return;
        }

        return if !$DBObject->Prepare(
            SQL =>
                'SELECT id, name, valid_id, node_comment, protocol, host, port, node_path, node_login, node_password, cluster_id '
                . 'FROM search_cluster_nodes WHERE name = ? AND cluster_id = ?',
            Bind => [ \$Param{Name}, \$Param{ClusterID} ]
        );

        my %NodeData;
        while ( my @Data = $DBObject->FetchrowArray() ) {
            %NodeData = (
                NodeID    => $Data[0],
                Name      => $Data[1],
                ValidID   => $Data[2],
                Comment   => $Data[3],
                Protocol  => $Data[4],
                Host      => $Data[5],
                Port      => $Data[6],
                Path      => $Data[7],
                Login     => $Data[8],
                Password  => $Data[9],
                ClusterID => $Data[10]
            );
        }

        return \%NodeData;
    }

    return if !$DBObject->Prepare(
        SQL =>
            'SELECT id, name, valid_id, node_comment, protocol, host, port, node_path, node_login, node_password, cluster_id '
            . 'FROM search_cluster_nodes WHERE id = ?',
        Bind => [ \$Param{NodeID} ]
    );

    my %NodeData;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %NodeData = (
            NodeID    => $Data[0],
            Name      => $Data[1],
            ValidID   => $Data[2],
            Comment   => $Data[3],
            Protocol  => $Data[4],
            Host      => $Data[5],
            Port      => $Data[6],
            Path      => $Data[7],
            Login     => $Data[8],
            Password  => $Data[9],
            ClusterID => $Data[10]
        );
    }

    return \%NodeData;
}

=head2 ClusterCommunicationNodeSetPassword()

set password for communication node

    my $Success = $ClusterObject->ClusterCommunicationNodeSetPassword(
        ClusterID => 1,
        Login => 'some-login',
        Password => 'qwe123',
        NodeID => 1,
        Action => "Add" # possible: "Add", "Update",
        PasswordClear => 1,
    );

=cut

sub ClusterCommunicationNodeSetPassword {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    NEEDED:
    for my $Needed (qw(ClusterID NodeID Action)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Cluster = $Self->ClusterGet(
        ClusterID => $Param{ClusterID},
    );

    my $Success;
    if ( $Cluster->{EngineID} ) {
        my $Module = "Kernel::System::Search::Auth::$Cluster->{EngineID}";

        my $Loaded = $SearchChildObject->_LoadModule(
            Module => $Module,
        );

        if ($Loaded) {

            # create AuthObject
            my $SearchAuthObject = $Kernel::OM->Get($Module);

            $Success = $SearchAuthObject->_ClusterCommunicationNodeSetPassword(
                NodeID        => $Param{NodeID},
                Password      => $Param{Password},
                Login         => $Param{Login},
                PasswordClear => $Param{PasswordClear},
            );
        }
    }

    if ( !$Success ) {
        my $OperationMsg = '(unknown action)';
        if ( $Param{Action} eq 'Add' ) {
            $OperationMsg = 'created';
        }
        elsif ( $Param{Action} eq 'Update' ) {
            $OperationMsg = 'updated';
        }
        $LogObject->Log(
            Priority => 'error',
            Message  => "Cluster communication node was $OperationMsg, but could not set a password for it!"
        );
    }

    return $Success;
}

=head2 ClusterCommunicationNodesImport()

import cluster communication nodes

    my $Result = $ClusterObject->ClusterCommunicationNodesImport(
        Content                => $Content,
        OverwriteExistingNodes => $OverwriteExistingNodes, # optional
        UserID                 => $UserID,
        ClusterID              => $ClusterID
     );

=cut

sub ClusterCommunicationNodesImport {
    my ( $Self, %Param ) = @_;

    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    NEEDED:
    for my $Needed (qw( Content UserID ClusterID )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $NodesData = $YAMLObject->Load( Data => $Param{Content} );

    if ( !IsArrayRefWithData($NodesData) ) {
        return {
            Success => 0,
            Message => "Couldn't read nodes configuration file. Please make sure the file is valid.",
        };
    }

    my $ClusterNodesList = $Self->ClusterCommunicationNodeList(
        ClusterID => $Param{ClusterID},
    );

    my @UpdatedNodes;
    my @AddedNodes;
    my @NodesErrors;

    NODETOIMPORT:
    for my $NodeToImport ( @{$NodesData} ) {

        next NODETOIMPORT if !$NodeToImport;
        next NODETOIMPORT if ref $NodeToImport ne 'HASH';

        my @ExistingNodes = @{$ClusterNodesList};
        @ExistingNodes = grep { $_->{Name} eq $NodeToImport->{Name} } @ExistingNodes;

        if ( $Param{OverwriteExistingNodes} && $ExistingNodes[0] ) {

            my $Success = $Self->ClusterCommunicationNodeUpdate(
                %{ $ExistingNodes[0] },
                Name          => $NodeToImport->{Name},
                Comment       => $NodeToImport->{Comment},
                ValidID       => $NodeToImport->{ValidID},
                Protocol      => $NodeToImport->{Protocol},
                Host          => $NodeToImport->{Host},
                Port          => $NodeToImport->{Port},
                Path          => $NodeToImport->{Path},
                Login         => $NodeToImport->{Login},
                UserID        => $Param{UserID},
                PasswordClear => 0,
            );

            if ($Success) {
                push @UpdatedNodes, $NodeToImport->{Name};
            }
            else {
                push @NodesErrors, $NodeToImport->{Name};
            }

        }
        else {
            my $NodeID = $Self->ClusterCommunicationNodeAdd(
                Name      => $NodeToImport->{Name},
                Comment   => $NodeToImport->{Comment},
                ValidID   => $NodeToImport->{ValidID},
                Protocol  => $NodeToImport->{Protocol},
                Host      => $NodeToImport->{Host},
                Port      => $NodeToImport->{Port},
                Path      => $NodeToImport->{Path},
                Login     => $NodeToImport->{Login},
                UserID    => $Param{UserID},
                ClusterID => $Param{ClusterID},
            );

            if ($NodeID) {
                push @AddedNodes, $NodeToImport->{Name};
            }
            else {
                push @NodesErrors, $NodeToImport->{Name};
            }
        }
    }

    return {
        Success      => 1,
        AddedNodes   => join( ', ', @AddedNodes ) || '',
        UpdatedNodes => join( ', ', @UpdatedNodes ) || '',
        NodesErrors  => join( ', ', @NodesErrors ) || '',
    };
}

=head2 NameExistsCheck()

return 1 if another cluster with this name already exists

    $Exist = $ClusterObject->NameExistsCheck(
        Name => 'Cluster1',
        ID   => 1, # optional
    );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM search_clusters WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Flag = 1 if !$Param{ID} || $Param{ID} ne $Row[0];
    }

    if ($Flag) {
        return 1;
    }

    return 0;
}

=head2 NodeNameExistsCheck()

return 1 if another node with this name already exists
in specified cluster

    $Exist = $ClusterObject->NodeNameExistsCheck(
        Name   => 'Cluster1',
        NodeID => 1, # optional
    );

=cut

sub NodeNameExistsCheck {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    NEEDED:
    for my $Needed (qw(ClusterID Name)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM search_cluster_nodes WHERE name = ? AND cluster_id = ?',
        Bind => [ \$Param{Name}, \$Param{ClusterID} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{NodeID} || $Param{NodeID} ne $Row[0] ) {
            $Flag = 1;
        }
    }

    if ($Flag) {
        return 1;
    }

    return 0;
}

=head2 ClusterInit()

set cluster as initialized

    my $Success = $ClusterObject->ClusterInit(
        ClusterID => $ClusterID,
    );

=cut

sub ClusterInit {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(ClusterID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    return if $Self->NameExistsCheck(
        Name => $Param{Name},
    );

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Do(
        SQL  => 'UPDATE search_clusters SET cluster_initialized = 1 WHERE id = ?',
        Bind => [ \$Param{ClusterID} ]
    );

    return 1;
}

1;
