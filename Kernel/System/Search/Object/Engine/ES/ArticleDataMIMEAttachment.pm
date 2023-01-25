# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Engine::ES::ArticleDataMIMEAttachment;

use strict;
use warnings;
use MIME::Base64;

use parent qw( Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Encode',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::Search::Object::Engine::ES::ArticleDataMIMEAttachment - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchArticleDataMIMEAttachmentObject = $Kernel::OM->Get('Kernel::System::Search::Object::Engine::ES::ArticleDataMIMEAttachment');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Module} = "Kernel::System::Search::Object::Engine::ES::ArticleDataMIMEAttachment";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'article_data_mime_attachment',    # index name on the engine/sql side
        IndexName     => 'ArticleDataMIMEAttachment',       # index name on the api side
        Identifier    => 'ID',                              # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        ArticleID => {
            ColumnName => 'article_id',
            Type       => 'Integer'
        },
        Filename => {
            ColumnName => 'filename',
            Type       => 'String'
        },
        ContentSize => {
            ColumnName => 'content_size',
            Type       => 'String'
        },
        ContentType => {
            ColumnName => 'content_type',
            Type       => 'String'
        },
        ContentID => {
            ColumnName => 'content_id',
            Type       => 'String'
        },
        ContentAlternative => {
            ColumnName => 'content_alternative',
            Type       => 'String'
        },
        Disposition => {
            ColumnName => 'disposition',
            Type       => 'String'
        },
        Content => {
            ColumnName => 'content',
            Type       => 'Blob'
        },
        CreateTime => {
            ColumnName => 'create_time',
            Type       => 'Date'
        },
        CreateBy => {
            ColumnName => 'create_by',
            Type       => 'Integer'
        },
        ChangeTime => {
            ColumnName => 'change_time',
            Type       => 'Date'
        },
        ChangeBy => {
            ColumnName => 'change_by',
            Type       => 'Integer'
        }
    };

    $Self->{ExternalFields} = {
        AttachmentContent => {
            ColumnName => 'attachment.content',
            Type       => 'Textarea',
            Alias      => 1,
        }
    };

    # get default config
    $Self->DefaultConfigGet();

    # load fields with custom field mapping
    $Self->_Load(
        Fields => $FieldMapping,
        Config => $Self->{Config},
    );

    return $Self;
}

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $DataToProcess = $Self->_FetchDataToProcess(
        %Param,
    );

    # build and return query
    my $BulkHelper = $Param{ConnectObject}->bulk_helper(
        index    => $Self->{Config}->{IndexRealName},
        pipeline => 'attachment',
    );

    for my $Object ( @{$DataToProcess} ) {
        $BulkHelper->create(
            {
                source => $Object,
            }
        );
    }

    my $Response = $BulkHelper->flush();

    if ( $Response->{errors} ) {
        $Response->{__Error} = 1;
    }

    return $Param{MappingObject}->ResponseIsSuccess(
        Response => $Response,
    );
}

sub ObjectIndexSet {
    my ( $Self, %Param ) = @_;

    my $DataToProcess = $Self->_FetchDataToProcess(
        %Param,
    );

    # build and return query
    my $BulkHelper = $Param{ConnectObject}->bulk_helper(
        index    => $Self->{Config}->{IndexRealName},
        pipeline => 'attachment',
    );

    for my $Object ( @{$DataToProcess} ) {
        $BulkHelper->index(
            {
                source => $Object,
            }
        );
    }

    my $Response = $BulkHelper->flush();

    if ( $Response->{errors} ) {
        $Response->{__Error} = 1;
    }

    return $Param{MappingObject}->ResponseIsSuccess(
        Response => $Response,
    );
}

sub SearchFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');

    my $ResultType = $Param{ResultType};

    # define supported result types
    my $SupportedResultTypes = $Self->{SupportedResultTypes};

    if ( !$SupportedResultTypes->{ $Param{ResultType} } ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Specified result type: $Param{ResultType} isn't supported! Default value: 'ARRAY' will be used instead.",
        );

        # revert to default result type
        $Param{ResultType} = 'ARRAY';
    }

    my $IndexName               = $Self->{Config}->{IndexName};
    my $GloballyFormattedResult = $Param{GloballyFormattedResult};

    # return only number of records without formatting its attribute
    if ( $Param{ResultType} eq "COUNT" ) {
        return {
            $IndexName => $GloballyFormattedResult->{$IndexName}->{ObjectData} // 0,
        };
    }

    my $ObjectData = $GloballyFormattedResult->{$IndexName}->{ObjectData};
    my $Fallback   = $SearchObject->{Fallback} || $Param{Fallback};

    if ( IsHashRefWithData( $Param{Fields}->{Content} ) ) {
        if ( !$Fallback || ( $Fallback && !$DBObject->GetDatabaseFunction('DirectBlob') ) ) {

            OBJECT:
            for ( my $i = 0; $i < scalar @{$ObjectData}; $i++ ) {
                next OBJECT if !$ObjectData->[$i]->{Content};
                $ObjectData->[$i]->{Content} = decode_base64( $ObjectData->[$i]->{Content} );
            }
        }
    }

    my $IndexResponse;

    if ( $Param{ResultType} eq "ARRAY" ) {
        $IndexResponse->{$IndexName} = $ObjectData;
    }
    elsif ( $Param{ResultType} eq "HASH" ) {

        my $Identifier = $Self->{Config}->{Identifier};
        if ( !$Identifier ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Missing '\$Self->{Config}->{Identifier} for $IndexName index.'",
                );
            }
            return;
        }

        $IndexResponse = { $IndexName => {} };

        DATA:
        for my $Data ( @{$ObjectData} ) {
            if ( !$Data->{$Identifier} ) {
                if ( !$Param{Silent} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message =>
                            "Could not get object identifier $Identifier for $IndexName index in the response!",
                    );
                }
                next DATA;
            }

            $IndexResponse->{$IndexName}->{ $Data->{$Identifier} } = $Data // {};
        }
    }

    return $IndexResponse;
}

sub Fallback {
    my ( $Self, %Param ) = @_;

    # attachment content is a field that's not available in fallback functionality
    delete $Param{Fields}->{AttachmentContent};

    # perform default sql object search
    my $FallbackSearchResult = $Self->SUPER::Fallback(
        %Param,
    );

    return $FallbackSearchResult;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchChildObject->ValidFieldsPrepare(
        Fields => $Fields,     # optional
        Object => $ObjectName,
    );

=cut

sub ValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    my $AttachmentBasicFields    = $Self->{Fields};
    my $AttachmentExternalFields = $Self->{ExternalFields};

    my %AllAttachmentFields = ( %{$AttachmentBasicFields}, %{$AttachmentExternalFields} );

    my $Fields;

    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        %{$Fields} = %AllAttachmentFields;
    }
    else {
        for my $ParamField ( @{ $Param{Fields} } ) {
            if ( $ParamField =~ m{^Attachment_(.+)} ) {
                my $AttachmentField = $1;
                if ( $AttachmentField && $AttachmentField eq '*' ) {
                    for my $AttachmentFieldName ( sort keys %AllAttachmentFields ) {
                        $Fields->{$AttachmentFieldName} = $AllAttachmentFields{$AttachmentFieldName};
                    }
                }
                else {
                    $Fields->{$AttachmentField} = $AllAttachmentFields{$AttachmentField}
                        if $AllAttachmentFields{$AttachmentField};
                }
            }
        }
    }

    return $Self->_PostValidFieldsPrepare(
        Fields => $Fields,
    );
}

=head2 _PostValidFieldsPrepare()

set fields return type if not specified

    my %Fields = $SearchTicketESObject->_PostValidFieldsPrepare(
        ValidFields => $ValidFields,
    );

=cut

sub _PostValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    return () if !IsHashRefWithData( $Param{Fields} );

    my %Fields = %{ $Param{Fields} };

    FIELD:
    for my $Field ( sort keys %Fields ) {
        $Fields{$Field} = $Self->{Fields}->{$Field};
        $Fields{$Field}->{ReturnType} = 'SCALAR' if !$Fields{$Field}->{ReturnType};
    }

    return %Fields;
}

sub _FetchDataToProcess {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    NEEDED:
    for my $Needed (qw(MappingObject)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    if ( $Param{ObjectID} && $Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter ObjectID and QueryParams cannot be used together!",
        );
        return;
    }
    elsif ( !$Param{ObjectID} && !$Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $Identifier = $Self->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    my $SQLSearchResult = $Self->SQLObjectSearch(
        QueryParams => $QueryParams,
        ResultType  => $Param{SQLSearchResultType} || 'ARRAY',
    );

    return if !$SQLSearchResult->{Success};

    # store content as base64
    RESULT:
    for my $Result ( @{ $SQLSearchResult->{Data} } ) {
        if ( $Result->{Content} ) {
            $EncodeObject->EncodeOutput( \$Result->{Content} );
            $Result->{Content} = encode_base64( $Result->{Content}, '' );
        }
    }

    return $SQLSearchResult->{Data};
}

1;
