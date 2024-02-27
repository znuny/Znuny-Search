# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Plugins::ES::Ingest;

use strict;
use warnings;

use JSON::PP;
use Kernel::System::VariableCheck qw(IsHashRefWithData);

use parent qw( Kernel::System::Search::Plugins::Base );

our @ObjectDependencies = (
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Plugins::ES::Ingest - Elasticsearch ingest plugin backend functions

=head1 DESCRIPTION

Main Elasticsearch ingest plugin functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchESIngestPluginObject = $Kernel::OM->Get('Kernel::System::Search::Plugins::ES::Ingest');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{PluginName} = "Ingest";

    return $Self;
}

=head2 ClusterInit()

initialize pipeline config

    my $ClusterInit = $SearchESIngestPluginObject->ClusterInit()

=cut

sub ClusterInit {
    my ( $Self, %Param ) = @_;

    my $SearchObject  = $Kernel::OM->Get('Kernel::System::Search');
    my $ConnectObject = $SearchObject->{ConnectObject};
    my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');

    my $Response;

    eval {
        $Response = $ConnectObject->transport()->perform_request(
            method => "PUT",
            path   => "_ingest/pipeline/attachment_nested",
            body   => {
                description => "Process with ingest attachment",
                processors  => [
                    {
                        "foreach" => {
                            field     => "AttachmentStorageTemp",
                            processor => {
                                attachment => {
                                    target_field => "_ingest._value.attachment",
                                    field        => "_ingest._value.Content",
                                }
                            }
                        }
                    },
                    {
                        script => {
                            description => "Set attachment content to clear temporary field",
                            lang        => "painless",
                            source      => "
                                for(int i=0;i<ctx.AttachmentStorageTemp.size();i++){
                                    ctx.AttachmentStorageClearTemp[ctx.AttachmentStorageTemp[i].ArticleID + '_' + ctx.AttachmentStorageTemp[i].ID] = ctx.AttachmentStorageTemp[i].attachment.content
                                }
                          "
                        }
                    },
                    {
                        script => {
                            description => "Remove temporary attribute",
                            lang        => "painless",
                            source      => "
                                ctx.AttachmentStorageTemp = null;
                          "
                        }
                    },
                    {
                        script => {
                            description => "Set content type to attachment",
                            lang        => "painless",
                            source      => "
                                ArrayList Articles = ctx.Articles;
                                for(int i=0;i<Articles.size();i++){
                                    long ArticleID = Articles.get(i).ArticleID;
                                    ArrayList Attachments = Articles.get(i).Attachments;
                                    for(int j=0; j<Attachments.size();j++){
                                        String AttachmentID = Attachments.get(j).ID;
                                        for(int k=0; k<ctx.AttachmentStorageClearTemp.size();k++){
                                            String Key = ArticleID + '_' + AttachmentID;
                                            if(ctx.AttachmentStorageClearTemp[Key] !== null){
                                                Attachments[j].AttachmentContent = ctx.AttachmentStorageClearTemp[Key];
                                            }
                                        }
                                    }
                                }
                          "
                        }
                    },
                    {
                        script => {
                            description => "Remove temporary attribute",
                            lang        => "painless",
                            source      => "
                                ctx.AttachmentStorageClearTemp = null;
                          "
                        }
                    }
                ]
            },
        );
    };

    my $Success = 0;

    if ($@) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Could not set pipeline \"attachment_nested_faq\" correctly! Error: $@",
        );
        return {
            PluginName => $Self->{PluginName},
            Status     => {
                Success => $Success,
            },
            Response     => $Response,
            ErrorMessage => $@,
        };
    }
    else {
        if (
            IsHashRefWithData($Response)
            && $Response->{acknowledged}
            && $Response->{acknowledged} == JSON::PP::true()
            )
        {
            $Success = 1;
        }

        return {
            PluginName => $Self->{PluginName},
            Status     => {
                Success => $Success,
            },
            Response => $Response,
        };
    }
}

1;
