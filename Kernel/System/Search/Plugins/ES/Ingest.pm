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

use Kernel::System::VariableCheck qw(:all);

use parent qw( Kernel::System::Search::Plugins::Base );

our @ObjectDependencies = (
    'Kernel::System::Search',
    'Kernel::System::DB',
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

    my $AttachmentNestedPipeline = $ConnectObject->transport()->perform_request(
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
                      ArrayList Articles = ctx.Articles;
                      ArrayList AttachmentStorageTemp = ctx.AttachmentStorageTemp;
                      for(int i=0;i<AttachmentStorageTemp.size();i++){
                        ctx.AttachmentStorageClearTemp['Attachment_'+AttachmentStorageTemp[i].ID] = AttachmentStorageTemp[i].attachment.content
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
                        ArrayList Attachments = Articles.get(i).Attachments;
                        for(int j=0; j<Attachments.size();j++){
                          String AttachmentID = Attachments.get(j).ID;
                          Attachments[j].AttachmentContent = ctx.AttachmentStorageClearTemp['Attachment_'+AttachmentID];
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

    return {
        PluginName => $Self->{PluginName},
        Status     => {
            Success => 1,
        }
    };
}

1;
