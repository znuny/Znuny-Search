# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Attachment;

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

    my $IndexName              = 'Ticket';
    my $IndexSearchObject      = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");
    my $ObjectIdentifierColumn = $IndexSearchObject->{Config}->{Identifier};
    my $ObjectID               = $Param{Data}->{$ObjectIdentifierColumn};

    return if !$IndexSearchObject->{Config}->{Settings}->{IndexAttachments};

    if ( !$ObjectID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need ObjectID ($ObjectIdentifierColumn) in event Data!"
        );
        return;
    }

    my $AdditionalParams;
    if ( $Param{Event} eq 'ArticleWriteAttachment' || $Param{Event} eq 'ArticleDeleteAttachment' ) {
        $AdditionalParams = { UpdateArticle => [ $Param{Data}->{ArticleID} ] };

        $SearchChildObject->IndexObjectQueueEntry(
            Index => $IndexName,
            Value => {
                Operation => 'ObjectIndexUpdate',
                ObjectID  => $ObjectID,
                Data      => $AdditionalParams,
            },
        );
    }

    return 1;
}

1;
