# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::Article;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::Article',
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Query::Article - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Article');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');

    for my $Property (
        qw(Fields SupportedOperators OperatorMapping DefaultSearchLimit
        SupportedResultTypes Config ExternalFields SearchableFields )
        )
    {
        $Self->{ 'Index' . $Property } = $IndexObject->{$Property};
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    $Self->{ActiveEngine} = $SearchObject->{Config}->{ActiveEngine};

    $MainObject->Require(
        "Kernel::System::Search::Object::EngineQueryHelper::$Self->{ActiveEngine}",
    );

    bless( $Self, $Type );

    return $Self;
}

1;
