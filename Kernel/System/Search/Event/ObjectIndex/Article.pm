# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Article;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};

    NEEDED:
    for my $Needed (qw(Data Event Config)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    NEEDED:
    for my $Needed (qw(FunctionName)) {
        next NEEDED if $Param{Config}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed in Config!"
        );
        return;
    }

    my $IndexName         = 'Article';
    my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");

    my $ObjectIdentifierColumn = $IndexSearchObject->{Config}->{Identifier};
    my $FunctionName           = $Param{Config}->{FunctionName};
    my $ObjectID               = $Param{Data}->{$ObjectIdentifierColumn};

    $SearchChildObject->IndexObjectQueueEntry(
        Index => 'Article',
        Value => {
            Operation => $FunctionName,
            ObjectID  => $Param{Data}->{ArticleID},
        },
    );

    my $Event = $Param{Event};
    my $AdditionalParams;
    if ( $Event eq 'ArticleCreate' ) {
        $AdditionalParams = { AddArticle => [ $Param{Data}->{ArticleID} ] };
    }
    elsif ( $Event eq 'ArticleUpdate' ) {
        $AdditionalParams = { UpdateArticle => [ $Param{Data}->{ArticleID} ] };
    }

    # update tickets that contains changed article
    $SearchChildObject->IndexObjectQueueEntry(
        Index => 'Ticket',
        Value => {
            Operation => 'ObjectIndexUpdate',
            ObjectID  => $Param{Data}->{TicketID},
            Data      => $AdditionalParams,
        },
    );

    return 1;
}

1;
