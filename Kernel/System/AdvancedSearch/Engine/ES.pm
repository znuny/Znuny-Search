# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AdvancedSearch::Engine::ES;

use strict;
use warnings;

use parent qw( Kernel::System::AdvancedSearch::Engine );

our @ObjectDependencies = (

);

=head1 NAME

Kernel::System::AdvancedSearch::Engine::ES - TO-DO

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

=head2 QueryExecute()

TO-DO

=cut

sub QueryExecute {
    my ( $Self, %Param ) = @_;

    return {
        Code     => '200',
        Response => {
            Describe => 'Response from ES Engine',
            Values   => {
                Objects => [
                    {
                        String => "Sneaky Rabbit"
                    },
                    {
                        String => "Howling Dog"
                    },
                    {
                        String => "Sleeping Owl"
                    },
                ],
            },
        },
    };
}

=head2 QueryMerge()

TO-DO

=cut

sub QueryMerge {
    my ( $Self, %Param ) = @_;

    return "Merged Query for ES";
}

1;
