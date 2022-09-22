# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::ArticleDataMIME;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::ArticleDataMIME',
);

=head1 NAME

Kernel::System::Search::Object::Query::ArticleDataMIME - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::ArticleDataMIME');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::ArticleDataMIME');

    # get index specified fields
    $Self->{IndexFields}               = $IndexObject->{Fields};
    $Self->{IndexDefaultValues}        = $IndexObject->{DefaultValues};
    $Self->{IndexSupportedOperators}   = $IndexObject->{SupportedOperators};
    $Self->{IndexOperatorMapping}      = $IndexObject->{OperatorMapping};
    $Self->{IndexDefaultSearchLimit}   = $IndexObject->{DefaultSearchLimit};
    $Self->{IndexSupportedResultTypes} = $IndexObject->{SupportedResultTypes};
    $Self->{IndexConfig}               = $IndexObject->{Config};

    bless( $Self, $Type );

    return $Self;
}

1;