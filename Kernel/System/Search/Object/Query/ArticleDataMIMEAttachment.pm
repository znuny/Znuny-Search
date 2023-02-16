# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::ArticleDataMIMEAttachment;

use strict;
use warnings;
use MIME::Base64;
use Kernel::System::VariableCheck qw(:all);

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment',
);

=head1 NAME

Kernel::System::Search::Object::Query::ArticleDataMIMEAttachment - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::ArticleDataMIMEAttachment');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment');

    for my $Property( qw(Fields SupportedOperators OperatorMapping DefaultSearchLimit
        SupportedResultTypes Config ExternalFields SearchableFields )) {
        $Self->{'Index' . $Property} = $IndexObject->{$Property};
    }

    bless( $Self, $Type );

    return $Self;
}

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    return 1 if $Param{Name} eq "AttachmentContent";
    return 1 if $Param{Name} eq "TicketID";

    return $Self->SUPER::_QueryFieldCheck(%Param);
}

sub Search {
    my ( $Self, %Param ) = @_;

    my $Query = $Self->SUPER::Search(%Param);

    if ( $Param{ResultType} ne 'COUNT' ) {

        # retrieve human readable attachment content
        push @{ $Query->{Query}->{Body}->{fields} }, 'AttachmentContent';
    }

    return $Query;
}

1;
