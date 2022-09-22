# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
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

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed parameters
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    for my $Needed (qw(FunctionName IndexName)) {
        if ( !$Param{Config}->{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed in Config!"
            );
            return;
        }
    }

    my $SearchChildObject      = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $IndexSearchObject      = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Config}->{IndexName}");
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
                Fields => [ [ $ObjectIdentifierColumn, 'CommunicationChannelID' ] ],
            );

            @{$ArticleIDsToDelete} = map { $_->{ArticleID} } @{ $ArticlesToDelete->{$IndexName} };
        }

        # event specified article to delete, delete only this article
        # TODO START uncomment when Search function will have support for
        # array in query params
        #          elsif(IsArrayRefWithData($ArticleIDsToDelete)) {
        #             $ArticlesToDelete = $SearchObject->Search(
        #                 Objects => ['Article'],
        #                 QueryParams => {
        #                     $ObjectIdentifierColumn => $ArticleIDsToDelete,
        #                 },
        #                 Fields => [[$ObjectIdentifierColumn, 'CommunicationChannelID']],
        #             );

        #             @{$ArticleIDsToDelete} = map {$_->{ArticleID} } @{$ArticlesToDelete->{ $IndexName }};
        #         }
        # TODO END

        return 1 if !IsArrayRefWithData($ArticleIDsToDelete) || !IsArrayRefWithData( $ArticlesToDelete->{$IndexName} );

        my $Success = $SearchObject->ObjectIndexRemove(
            Index    => 'Article',
            ObjectID => $ArticleIDsToDelete,
            Refresh  => 1,
        );

        # after succesfull article deletion
        # there is a need to delete all it's data from
        # linked tables
        # those are identified by communication channel
        if ($Success) {
            my $CommunicationChannelObject = $Kernel::OM->Get('Kernel::System::CommunicationChannel');
            my %CommunicationChannels;

            # identify valid indexes
            my %ValidIndexes;
            my @IndexList = $SearchObject->IndexList();
            for my $IndexRealName (@IndexList) {
                my $IsValid = $SearchChildObject->IndexIsValid(
                    IndexName => $IndexRealName,
                    RealName  => 1,
                );
                if ($IsValid) {
                    $ValidIndexes{$IndexRealName} = $IsValid;
                }
            }

            # iterate through all articles ids to delete
            for my $ArticleDataToDelete ( @{ $ArticlesToDelete->{$IndexName} } ) {

                # get communication channel data for article
                if ( !$CommunicationChannels{ $ArticleDataToDelete->{CommunicationChannelID} } ) {
                    %{ $CommunicationChannels{ $ArticleDataToDelete->{CommunicationChannelID} } } =
                        $CommunicationChannelObject->ChannelGet(
                        ChannelID => $ArticleDataToDelete->{CommunicationChannelID},
                        );
                }
                my $ChannelData
                    = $CommunicationChannels{ $ArticleDataToDelete->{CommunicationChannelID} }->{ChannelData};

                # Based on different communication channels there will
                # be differences in linked data tables for actual article.
                # Get a proper tables to clear data for actually iterated
                # article id.
                for my $ArticleDataTable ( @{ $ChannelData->{ArticleDataTables} } ) {

                    # article linked table needs to be available
                    if ( $ValidIndexes{$ArticleDataTable} ) {

                        my $Success = $SearchObject->ObjectIndexRemove(
                            Index       => $ValidIndexes{$ArticleDataTable},
                            QueryParams => {
                                ArticleID => $ArticleDataToDelete->{ArticleID},
                            },
                            Refresh => 1,
                        );
                    }
                }

                # note: for now deleting article data from Article.* indexes
                # are supported
            }
        }
        else {
            my $ArticleIDStrg = join ',', @{$ArticleIDsToDelete};
            $LogObject->Log(
                Priority => 'error',
                Message  => "Could not remove articles from search engine with ids: $ArticleIDStrg",
            );
        }
        return 1;
    }

    my %QueryParam = (
        Index    => $Param{Config}->{IndexName},
        ObjectID => $ObjectIDData,
    );

    my $FunctionName = $Param{Config}->{FunctionName};

    # prevent error code 500 when engine index failed
    eval {
        $SearchObject->$FunctionName(
            %QueryParam,
            Refresh => 1,    # live indexing should be refreshed every time
        );
    };
    if ($@) {
        $LogObject->Log(
            Priority => 'error',
            Message  => $@,
        );
    }

    return 1;
}

1;
