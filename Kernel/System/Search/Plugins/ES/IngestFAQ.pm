# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Plugins::ES::IngestFAQ;

use strict;
use warnings;

use JSON::PP;
use Kernel::System::VariableCheck qw(IsHashRefWithData);

use parent qw( Kernel::System::Search::Plugins::Base );

our @ObjectDependencies = (
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Plugins::ES::IngestFAQ - Elasticsearch IngestFAQ plugin backend functions

=head1 DESCRIPTION

Main Elasticsearch IngestFAQ plugin functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchESIngestFAQPluginObject = $Kernel::OM->Get('Kernel::System::Search::Plugins::ES::IngestFAQ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{PluginName} = "IngestFAQ";

    return $Self;
}

=head2 ClusterInit()

initialize pipeline config

    my $ClusterInit = $SearchESIngestFAQPluginObject->ClusterInit()

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
            path   => "_ingest/pipeline/attachment_nested_faq",
            body   => {
                description => "Process with ingest attachment for FAQ",
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
                                    ctx.AttachmentStorageClearTemp[Integer.toString(ctx.AttachmentStorageTemp[i].FileID)] = ctx.AttachmentStorageTemp[i].attachment.content
                                }
                          "
                        }
                    },
                    {
                        script => {
                            description => "Remove temporary attribute",
                            lang        => "painless",
                            source      => "
                                ctx.remove('AttachmentStorageTemp');
                          "
                        }
                    },
                    {
                        script => {
                            description => "Set content type to attachment",
                            lang        => "painless",
                            source      => "
                                ArrayList Attachments = ctx.Attachments;
                                for(int i=0; i<Attachments.size();i++){
                                    long AttachmentID = Attachments.get(i).FileID;
                                    if(ctx.AttachmentStorageClearTemp[''+AttachmentID] !== null){
                                        Attachments[i].AttachmentContent = ctx.AttachmentStorageClearTemp[''+AttachmentID];
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
                                ctx.remove('AttachmentStorageClearTemp');
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
            Response => $Response,
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
