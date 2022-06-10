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

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw( Objects QueryParams Operation )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my %Result;
    my @Queries;

    my $FunctionName = $Param{Operation};

    OBJECT:
    for my $Object ( @{ $Param{Objects} } ) {

        my $ObjectModule = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Object}");

        my $Data = $ObjectModule->$FunctionName(
            QueryParams => $Param{QueryParams},
        );

        # my $Data = {    # MOCK-UP
        #     Error    => 0,
        #     Fallback => {
        #         Continue => 1
        #     },
        #     Query => 'Queries 1'
        # };

        #         TODO Add information about possible errors in each query
        #         $Result{Error}    = $Data->{Error};
        #         $Result{Fallback} = $Data->{Fallback};    # THIS POSSIBLE SHOULD SLICE RESPONSE PER OBJECT MODULE.

        # TODO: Check for possibility of handling fallbacks mixed with engine requests.
        $Data->{Object} = $Object;
        push @Queries, $Data;
    }

    $Result{Queries} = \@Queries;

    return \%Result;
}

1;
