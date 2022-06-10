# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::Search::Object - TO-DO

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE


=head2 new()

TO-DO

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 ObjectIndexAdd()

TO-DO

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexGet()

TO-DO

=cut

sub ObjectIndexGet {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexRemove()

TO-DO

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 Fallback()

TO-DO

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 QueryPrepare()

TO-DO

=cut

sub QueryPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    for my $Name (qw( Objects QueryParams Operation MappingObject Config)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my %Result = ();
    my @Queries;

    my $FunctionName = $Param{Operation};

    OBJECT:
    for my $Object ( @{ $Param{Objects} } ) {

        my $Loaded = $MainObject->Require(
            "Kernel::System::Search::Object::Query::${Object}",
            Silent => 0,
        );
        if ( !$Loaded ) {
            return;
        }
        my $ObjectModule = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Object}");

        # my $Data = { # Response example
        #     Error    => 0,
        #     Fallback => {
        #         Enable => 1
        #     },
        #     Query => 'Queries 1'
        # };
        my $Data = $ObjectModule->$FunctionName(
            QueryParams   => $Param{QueryParams},
            MappingObject => $Param{MappingObject},
            ActiveEngine  => $Param{ActiveEngine},
            Config        => $Param{Config},
            Object        => $Object,
        );
        $Data->{Object} = $Object;
        push @Queries, $Data;
    }

    $Result{Queries} = \@Queries;

    return \%Result;
}

1;
