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

    my %Result;

    my @Queries;

    OBJECT:
    for my $Object ( @{ $Param{Objects} } ) {

        my $ObjectModule = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Object}");

        my $Data = $ObjectModule->Search(
            %Param,
            IndexName => $Object,
        );

        # my $Data = {    # MOCK-UP
        #     Error    => 0,
        #     Fallback => {
        #         Continue => 1
        #     },
        #     Query => 'Queries 1'
        # };

        $Result{Error}    = $Data->{Error};
        $Result{Fallback} = $Data->{Fallback};    # THIS POSSIBLE SHOULD SLICE RESPONSE PER OBJECT MODULE.

        # TODO: Check for possibility of handling fallbacks mixed with engine requests.

        push @Queries, $Data->{Query};
    }

    $Result{Queries} = \@Queries;

    return \%Result;
}

1;
