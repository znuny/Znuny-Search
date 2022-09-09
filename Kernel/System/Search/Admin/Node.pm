# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Admin::Node;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Cluster',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Search::Admin::Node - admin node view engine lib

=head1 DESCRIPTION

Cluster node admin backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

    my $SearchAdminNodeObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Node');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 BuildNodeSection()

Build add/edit communication node section. There is possibility to override
this function and template for specific engine.

    my $NodeAdd = $NodeObject->BuildNodeSection(
        ClusterID => $ClusterID,
        UserID => $UserID,
        Action => 'Add' # possible: "Add", "Edit"
    );

    my $NodeEdit = $NodeObject->BuildNodeSection(
        NodeID => $NodeID,
        UserID => $UserID,
        Action => 'Add' # possible: "Add", "Edit"
    );

=cut

sub BuildNodeSection {
    my ( $Self, %Param ) = @_;

    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::Search' => {
            Silent => 1,
        },
    );

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    for my $Name (qw(UserID Action)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $EngineID  = $Param{EngineID} || 'ES';
    my %ValidList = $ValidObject->ValidList();

    if ( $Param{Action} eq 'NodeChange' ) {

        my $NodeData = $SearchClusterObject->ClusterCommunicationNodeGet(
            NodeID => $Param{NodeID}
        );

        if ( !IsHashRefWithData($NodeData) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Node not found.",
            );
            return;
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $LayoutObject->Block( Name => 'ActionOverview' );
        $LayoutObject->Block( Name => 'ActionDelete' );

        my $ProtocolStrg = $LayoutObject->BuildSelection(
            Data => {
                'http'  => 'HTTP',
                'https' => 'HTTPS'
            },
            Name         => 'Protocol',
            SelectedID   => $NodeData->{Protocol},
            PossibleNone => 0,
            Translate    => 1,
            Class        => 'Modernize',
        );

        # create the validity select
        my $ValidtyStrg = $LayoutObject->BuildSelection(
            Data         => \%ValidList,
            Name         => 'ValidID',
            SelectedID   => $NodeData->{ValidID} || 1,
            PossibleNone => 0,
            Translate    => 1,
            Class        => 'Modernize',
        );

        # remove password from data
        # just in case someone tried to
        # use it's value in template
        undef $Param{Password};
        undef $NodeData->{Password};
        $Output .= $LayoutObject->Output(
            TemplateFile => "AdminSearch/$EngineID/Node",
            Data         => {
                %Param,
                %{$NodeData},
                ValidtyStrg  => $ValidtyStrg,
                ProtocolStrg => $ProtocolStrg,
            },
        );

        $Output .= $LayoutObject->Footer();

        return $Output;

    }
    elsif ( $Param{Action} eq 'NodeAdd' ) {

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $LayoutObject->Block( Name => 'ActionOverview' );

        my $ProtocolStrg = $LayoutObject->BuildSelection(
            Data => {
                'http'  => 'HTTP',
                'https' => 'HTTPS'
            },
            Name         => 'Protocol',
            SelectedID   => $Param{Protocol} || 'https',
            PossibleNone => 0,
            Translate    => 1,
            Class        => 'Modernize',
        );

        # create the validity select
        my $ValidtyStrg = $LayoutObject->BuildSelection(
            Data         => \%ValidList,
            Name         => 'ValidID',
            SelectedID   => $Param{ValidID} || '1',
            PossibleNone => 0,
            Translate    => 1,
            Class        => 'Modernize',
        );

        # remove password from data
        # just in case someone tried to
        # use it's value in template
        undef $Param{Password};

        $Output .= $LayoutObject->Output(
            TemplateFile => "AdminSearch/$EngineID/Node",
            Data         => {
                %Param,
                ValidtyStrg  => $ValidtyStrg,
                ProtocolStrg => $ProtocolStrg,
            },
        );

        $Output .= $LayoutObject->Footer();

        return $Output;
    }
}

1;
