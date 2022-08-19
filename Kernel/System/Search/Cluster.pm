# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
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

    my $ClusterList = $ClusterObject->ClusterList()

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

    my $ClusterList = $ClusterObject->ClusterGet(
        ClusterID => $ClusterID
    )

=cut

sub ClusterGet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Needed (qw(ClusterID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, remote_system, engine, valid_id, create_time, change_time, description '
            . 'FROM search_clusters WHERE id = ?',
        Bind  => [ \$Param{ClusterID} ],
        Limit => 1,
    );

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ClusterID    => $Data[0],
            Name         => $Data[1],
            RemoteSystem => $Data[2],
            EngineID     => $Data[3],
            ValidID      => $Data[4],
            CreateTime   => $Data[5],
            ChangeTime   => $Data[6],
            Description  => $Data[7]
        );
    }

    return \%Data;
}

=head2 ClusterAdd()

add cluster

    my $ClusterList = $ClusterObject->ClusterAdd(
        Name => $Name,
        RemoteSystem => $RemoteSystem,
        ValidID => $ValidID,
        EngineID => $EngineID,
        UserID => $UserID,
    )

=cut

sub ClusterAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Needed (qw(Name RemoteSystem ValidID EngineID UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    return if $Self->NameExistsCheck(
        Name => $Param{Name},
    );

    $Param{Description} ||= '';

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Do(
        SQL =>
            'INSERT INTO search_clusters (name, remote_system, valid_id, description, engine,'
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{RemoteSystem}, \$Param{ValidID}, \$Param{Description},
            \$Param{EngineID}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    return 1;
}

=head2 ClusterDelete()

remove cluster

    my $ClusterList = $ClusterObject->ClusterDelete(
        ClusterID => $ClusterID
    )

=cut

sub ClusterDelete {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    for my $Needed (qw(ClusterID UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
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

    my $ClusterList = $ClusterObject->ClusterUpdate(
        ClusterID => $ClusterID,
        %ClusterData,
    )

=cut

sub ClusterUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    for my $Needed (qw(ClusterID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %FieldMapping = (
        ValidID      => 'valid_id',
        Description  => 'description',
        RemoteSystem => 'remote_system',
        Name         => 'name',
        EngineID     => 'engine'
    );

    return if $Self->NameExistsCheck(
        ID   => $Param{ClusterID},
        Name => $Param{Name},
    );

    my %Attributes;
    ATTRIBUTE:
    for my $Attribute (qw(ValidID Description RemoteSystem Name EngineID)) {
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

receive data of first valid(active) clusters

    my $ClusterList = $ClusterObject->ActiveClusterGet(
        ClusterID => $ClusterID,
        %ClusterData,
    )

=cut

sub ActiveClusterGet {
    my ( $Self, %Param ) = @_;

    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, remote_system, engine, valid_id, create_time, change_time, description '
            . 'FROM search_clusters WHERE valid_id IN (' . join ', ', $ValidObject->ValidIDsGet() . ') LIMIT 1',
    );

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ClusterID    => $Data[0],
            Name         => $Data[1],
            RemoteSystem => $Data[2],
            Engine       => $Data[3],
            ValidID      => $Data[4],
            CreateTime   => $Data[5],
            ChangeTime   => $Data[6],
            Description  => $Data[7]
        );
    }

    return \%Data;
}

=head2 NameExistsCheck()

return 1 if another cluster with this name already exists

    $Exist = $ClusterObject->NameExistsCheck(
        Name => 'Cluster1',
        ID => 1, # optional
    );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM search_clusters WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{ID} || $Param{ID} ne $Row[0] ) {
            $Flag = 1;
        }
    }

    if ($Flag) {
        return 1;
    }

    return 0;
}

1;
