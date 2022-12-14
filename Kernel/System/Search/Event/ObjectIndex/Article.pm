# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
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
    'Kernel::System::CommunicationChannel',
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

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
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
    for my $Needed (qw(FunctionName IndexName)) {
        next NEEDED if $Param{Config}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed in Config!"
        );
        return;
    }

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Config}->{IndexName}");

    my $ObjectIdentifierColumn = $IndexSearchObject->{Config}->{Identifier};
    my $ObjectIDData           = $Param{Data}->{$ObjectIdentifierColumn};
    my $IndexName              = $IndexSearchObject->{Config}->{IndexName};

    if ( $Param{Config}->{FunctionName} eq 'ObjectIndexRemove' ) {

        my $ArticleIDsToDelete = $ObjectIDData;
        my $ArticlesToDelete;

        # event didn't sent ArticleID in data, but there is TicketID
        # in that case remove all articles from this ticket
        if ( !IsArrayRefWithData($ArticleIDsToDelete) && $Param{Data}->{TicketID} ) {
            $ArticlesToDelete = $SearchObject->Search(
                Objects     => ['Article'],
                QueryParams => {
                    TicketID => $Param{Data}->{TicketID},
                },
                Fields => [ [ 'Article_' . $ObjectIdentifierColumn, 'Article_CommunicationChannelID' ] ],
            );

            @{$ArticleIDsToDelete} = map { $_->{ArticleID} } @{ $ArticlesToDelete->{$IndexName} };
        }

        # event specified article to delete, delete only this article
        elsif ( IsArrayRefWithData($ArticleIDsToDelete) || IsNumber($ArticleIDsToDelete) ) {
            $ArticlesToDelete = $SearchObject->Search(
                Objects     => ['Article'],
                QueryParams => {
                    $ObjectIdentifierColumn => $ArticleIDsToDelete,
                },
                Fields => [ [ 'Article_' . $ObjectIdentifierColumn, 'Article_CommunicationChannelID' ] ],
            );
            @{$ArticleIDsToDelete} = map { $_->{ArticleID} } @{ $ArticlesToDelete->{$IndexName} };
        }

        return 1
            if !IsArrayRefWithData($ArticleIDsToDelete) || !IsArrayRefWithData( $ArticlesToDelete->{$IndexName} );

        my $Success = $SearchObject->ObjectIndexRemove(
            Index    => 'Article',
            ObjectID => $ArticleIDsToDelete,
            Refresh  => 1,
        );

        # after successful article deletion
        # there is a need to delete all its data from linked tables
        # those are identified by communication channel
        if ($Success) {
            $Self->_LinkedTablesArticleAction(
                FunctionName => $Param{Config}->{FunctionName},
                Articles     => $ArticlesToDelete,
                IndexName    => $IndexName,
            );
        }
        else {
            my $ArticleIDStrg = join ',', @{$ArticleIDsToDelete};
            $LogObject->Log(
                Priority => 'error',
                Message  => "Could not remove articles with IDs $ArticleIDStrg from search engine.",
            );
        }

        return 1;
    }

    my %QueryParam = (
        Index    => $Param{Config}->{IndexName},
        ObjectID => $ObjectIDData,
    );

    my $UpdateLinkedTables = 1;

    if ( $Param{Event} eq 'TicketMerge' ) {
        my $ArticleData = $SearchObject->Search(
            Objects     => ['Article'],
            QueryParams => {
                TicketID => $Param{Data}->{TicketID},
            },
            Fields     => [ ['Article_ArticleID'] ],
            ResultType => 'ARRAY',
            SortBy     => ['ArticleID'],
            OrderBy    => 'Up',
        );

        # TODO: temporary workaround until support for "OR" connection in search
        if ( IsArrayRefWithData( $ArticleData->{Article} ) ) {
            @{ $ArticleData->{Article} } = grep { $_->{ArticleID} } @{ $ArticleData->{Article} };
        }

        # ticket merge event change relation for id of merged ticket articles
        # to main ticket but afterwards creates one article in merged ticket
        # it needs to be ignored as it will be indexed via ArticleCreate event itself, not here
        delete $ArticleData->{Article}[-1];

        @{ $QueryParam{ObjectID} } = map { $_->{ArticleID} } @{ $ArticleData->{Article} };
        undef $UpdateLinkedTables;

        # update main ticket (ticket that another one was merged within)
        $SearchObject->ObjectIndexSet(
            Index    => 'Ticket',
            ObjectID => $Param{Data}->{MainTicketID},
        );
    }

    my $FunctionName = $Param{Config}->{FunctionName};

    my $Success = $SearchObject->$FunctionName(
        %QueryParam,
        Refresh => 1,    # live indexing should be refreshed every time
    );

    if ( $Success && $UpdateLinkedTables ) {
        my $ArticlesToPerformAction = $SearchObject->Search(
            Objects     => ['Article'],
            QueryParams => {
                ArticleID => $Param{Data}->{ArticleID},
            },
            Fields       => [ [ 'Article_' . $ObjectIdentifierColumn, 'Article_CommunicationChannelID' ] ],
            UseSQLSearch => 1,
        );

        $Self->_LinkedTablesArticleAction(
            FunctionName => $Param{Config}->{FunctionName},
            Articles     => $ArticlesToPerformAction,
            IndexName    => $IndexName,
        );
    }
    elsif ($UpdateLinkedTables) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "The $FunctionName operation could not be performed for Article with ID $ObjectIDData.",
        );
    }

    # update ticket that contains changed article
    $SearchObject->ObjectIndexSet(
        Index    => 'Ticket',
        ObjectID => $Param{Data}->{TicketID},
    );

    return 1;
}

sub _LinkedTablesArticleAction {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(FunctionName Articles IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $CommunicationChannelObject = $Kernel::OM->Get('Kernel::System::CommunicationChannel');
    my $SearchObject               = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject          = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $FunctionName               = $Param{FunctionName};

    my %CommunicationChannels;

    # identify valid indexes
    my %ValidIndexes;
    my @IndexList = $SearchObject->IndexList();

    INDEXREALNAME:
    for my $IndexRealName (@IndexList) {
        my $IndexName = $SearchChildObject->IndexIsValid(
            IndexName => $IndexRealName,
            RealName  => 1,
        );

        next INDEXREALNAME if !$IndexName;
        $ValidIndexes{$IndexRealName} = $IndexName;
        $ValidIndexes{Modules}{$IndexRealName}
            = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");
    }

    my $UseSQLSearch = $FunctionName eq 'ObjectIndexRemove' ? 0 : 1;

    # iterate through all IDs of articles to delete
    for my $ArticleData ( @{ $Param{Articles}->{ $Param{IndexName} } } ) {

        # get communication channel data for article
        if ( !$CommunicationChannels{ $ArticleData->{CommunicationChannelID} } ) {
            %{ $CommunicationChannels{ $ArticleData->{CommunicationChannelID} } } =
                $CommunicationChannelObject->ChannelGet(
                ChannelID => $ArticleData->{CommunicationChannelID},
                );
        }
        my $ChannelData = $CommunicationChannels{ $ArticleData->{CommunicationChannelID} }->{ChannelData};

        # Based on different communication channels there will
        # be a differences in linked data tables for actual article.
        # Get a proper table to clear data for actually iterated
        # article id.

        ARTICLEDATATABLE:
        for my $ArticleDataTable ( @{ $ChannelData->{ArticleDataTables} } ) {

            # article linked table needs to be available
            next ARTICLEDATATABLE if !$ValidIndexes{$ArticleDataTable};

            my $ArticlesToDelete = $SearchObject->Search(
                Objects     => [ $ValidIndexes{$ArticleDataTable} ],
                QueryParams => {
                    ArticleID => $ArticleData->{ArticleID},
                },
                UseSQLSearch => $UseSQLSearch,
                Fields       => [
                    [
                        "$ValidIndexes{$ArticleDataTable}_"
                            . $ValidIndexes{Modules}{$ArticleDataTable}->{Config}->{Identifier}
                    ]
                ]
            );

            my @ArticleIDs = map { $_->{ $ValidIndexes{Modules}{$ArticleDataTable}->{Config}->{Identifier} } }
                @{ $ArticlesToDelete->{ $ValidIndexes{$ArticleDataTable} } };

            next ARTICLEDATATABLE if !scalar @ArticleIDs;

            my %Mapping = (
                ObjectIndexRemove => {
                    QueryParams => {
                        ArticleID => $ArticleData->{ArticleID},
                    },
                },
                ObjectIndexUpdate => {
                    ObjectID => \@ArticleIDs,
                },
                ObjectIndexAdd => {
                    ObjectID => \@ArticleIDs,
                }
            );

            my $Success = $SearchObject->$FunctionName(
                Index => $ValidIndexes{$ArticleDataTable},
                %{ $Mapping{$FunctionName} },
                Refresh => 1,
            );
        }

        # note: for now add/update/remove article data from Article.* indexes
        # are supported
    }

    return 1;
}

1;
