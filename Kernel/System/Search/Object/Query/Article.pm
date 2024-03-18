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
use utf8;

use Kernel::System::VariableCheck qw(:all);

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
        SupportedResultTypes Config ExternalFields AdditionalFields SearchableFields )
        )
    {
        $Self->{ 'Index' . $Property } = $IndexObject->{$Property};
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    $Self->{ActiveEngine} = $SearchObject->{Config}->{ActiveEngine} // '';

    if ( !$SearchObject->{Fallback} ) {
        $MainObject->Require(
            "Kernel::System::Search::Object::EngineQueryHelper::$Self->{ActiveEngine}",
        );
    }

    bless( $Self, $Type );

    return $Self;
}

=head2 _QueryParamsPrepare()

prepare valid structure output for query params

    my $QueryParams = $SearchQueryTicketObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
        NoMappingCheck => $Param{NoMappingCheck},
    );

=cut

sub _QueryParamsPrepare {
    my ( $Self, %Param ) = @_;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my %QueryParams;

    if ( IsHashRefWithData( $Param{QueryParams} ) ) {
        %QueryParams = %{ $Param{QueryParams} };
    }

    # support permissions
    if ( $QueryParams{UserID} ) {

        # get users groups
        my %GroupList = $GroupObject->PermissionUserGet(
            UserID => delete $QueryParams{UserID},
            Type   => delete $QueryParams{Permissions} || 'ro',
        );

        push @{ $QueryParams{GroupID} }, keys %GroupList;
    }

    # additional check if valid groups was specified
    # based on UserID and GroupID params
    # if no, treat it as there is no permissions
    # empty response will be retrieved
    if ( !$Param{NoPermissions} && !IsArrayRefWithData( $QueryParams{GroupID} ) ) {
        $QueryParams{GroupID} = [-1];
    }

    my $SearchParams = $Self->SUPER::_QueryParamsPrepare(
        %Param,
        QueryParams => \%QueryParams,
    ) // {};

    if ( ref $SearchParams eq 'HASH' && $SearchParams->{Error} ) {
        return $SearchParams;
    }

    return $SearchParams;
}

=head2 _QueryFieldCheck()

check specified field for index

    my $Result = $SearchQueryTicketObject->_QueryFieldCheck(
        Name => 'property',
        Value => '1', # by default value is passed but is not used
                      # in standard query module
    );

=cut

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    return 1 if $Param{Name} eq "GroupID";
    return $Self->SUPER::_QueryFieldCheck(%Param);
}

1;
