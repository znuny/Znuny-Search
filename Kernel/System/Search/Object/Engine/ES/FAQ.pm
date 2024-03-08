# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## nofilter(TidyAll::Plugin::Znuny4OTRS::Perl::ObjectManagerDirectCall)

package Kernel::System::Search::Object::Engine::ES::FAQ;

use strict;
use warnings;
use MIME::Base64;
use POSIX qw/ceil/;

use parent qw( Kernel::System::Search::Object::Default::FAQ Kernel::System::Search::Object::Engine::ES );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (

);

=head1 NAME

Kernel::System::Search::Object::Engine::ES::FAQ - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don' t use the constructor directly, use the ObjectManager instead :

    my $SearchFAQESObject = $Kernel::OM->Get('Kernel::System::Search::Object::Engine::ES::FAQ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Module} = 'Kernel::System::Search::Object::Engine::ES::FAQ';

    # specify base config for index
    $Self->{Config} = {
        IndexRealName        => 'faq_item',    # index name on the engine/sql side
        IndexName            => 'FAQ',         # index name on the api side
        Identifier           => 'ItemID',      # column name that represents object id in the field mapping
        ChangeTimeColumnName => 'Changed',     # column representing time of updated data entry
    };

    # load settings for index
    $Self->{Config}->{Settings} = $Self->LoadSettings(
        IndexName => $Self->{Config}->{IndexName},
    );

    # define schema for data
    my $FieldMapping = {
        ItemID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        Number => {
            ColumnName => 'f_number',
            Type       => 'Long'
        },
        Title => {
            ColumnName => 'f_subject',
            Type       => 'String'
        },
        Name => {
            ColumnName => 'f_name',
            Type       => 'String'
        },
        LanguageID => {
            ColumnName => 'f_language_id',
            Type       => 'Integer'
        },
        StateID => {
            ColumnName => 'state_id',
            Type       => 'Integer'
        },
        CategoryID => {
            ColumnName => 'category_id',
            Type       => 'Integer'
        },
        Approved => {
            ColumnName => 'approved',
            Type       => 'Integer'
        },
        ValidID => {
            ColumnName => 'valid_id',
            Type       => 'Integer'
        },
        ContentType => {
            ColumnName => 'content_type',
            Type       => 'String'
        },
        Keywords => {
            ColumnName => 'f_keywords',
            Type       => 'Textarea'
        },
        Field1 => {
            ColumnName => 'f_field1',
            Type       => 'Textarea'
        },
        Field2 => {
            ColumnName => 'f_field2',
            Type       => 'Textarea'
        },
        Field3 => {
            ColumnName => 'f_field3',
            Type       => 'Textarea'
        },
        Field4 => {
            ColumnName => 'f_field4',
            Type       => 'Textarea'
        },
        Field5 => {
            ColumnName => 'f_field5',
            Type       => 'Textarea'
        },
        Field6 => {
            ColumnName => 'f_field6',
            Type       => 'Textarea'
        },
        Created => {
            ColumnName => 'created',
            Type       => 'Date'
        },
        CreatedBy => {
            ColumnName => 'created_by',
            Type       => 'Integer'
        },
        Changed => {
            ColumnName => 'changed',
            Type       => 'Date'
        },
        ChangedBy => {
            ColumnName => 'changed_by',
            Type       => 'Integer'
        },
    };

    $Self->{ExternalFields} = {
        GroupID => {
            ColumnName => 'group_id',
            Type       => 'Integer',
            Alias      => 0,
        },
    };

    $Self->{AttachmentFields} = {
        FileID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        Filename => {
            ColumnName => 'filename',
            Type       => 'String'
        },
        Filesize => {
            ColumnName => 'content_size',
            Type       => 'String'
        },
        FilesizeRaw => {
            ColumnName => '',
            Type       => 'Long'
        },
        ContentType => {
            ColumnName => 'content_type',
            Type       => 'String'
        },
        Content => {
            ColumnName => 'content',
            Type       => 'Blob'
        },
        AttachmentContent => {
            ColumnName => '',
            Type       => 'Textarea',
            Alias      => 1,
        },
        Inline => {
            ColumnName => 'inlineattachment',
            Type       => 'Integer',
        },
        Created => {
            ColumnName => 'created',
            Type       => 'Date'
        },
        CreatedBy => {
            ColumnName => 'created_by',
            Type       => 'Integer'
        },
        Changed => {
            ColumnName => 'changed',
            Type       => 'Date'
        },
        ChangedBy => {
            ColumnName => 'changed_by',
            Type       => 'Integer'
        },
    } if $Self->{Config}->{Settings}->{IndexAttachments};

    # define searchable fields
    # that can be used as query parameters
    # for either indexing or searching
    $Self->{SearchableFields} = {
        SQL    => '*',
        Engine => '*',
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

=head2 Search()

Prepare data and parameters for engine or fallback search,
then execute search.

    my $Result = $SearchFAQESObject->Search(
        ID            => $Param{ID},
        Objects       => ['FAQ'],
        Counter       => $Counter,
        MappingObject => $MappingObject},
        EngineObject  => $EngineObject},
        ConnectObject => $ConnectObject},
        GlobalConfig  => $Config},
    );

On executing FAQ search by Kernel::System::Search:
    my $Result = $Kernel::OM->Get('Kernel::System::Search')->Search(
        Objects => ["FAQ"],
        QueryParams => {
            # standard FAQ fields
            ItemID => 1,
            Number => 2022101276000016,
            Title => 'some-title',
            Name => 'faq-name',
            LanguageID => 1,
            StateID => 1,
            CategoryID => 1,
            Approved => 1,
            ValidID => 1,
            ContentType => 'text/html',
            Keywords => 'some keywords here',
            Field1 => 'field1',
            Field2 => 'field2',
            Field3 => 'field3',
            Field4 => 'field4',
            Field5 => 'field5',
            Field6 => 'field6',
            Created => "2022-08-17 13:13:23",
            CreateBy => 1,
            Changed => "2022-08-17 13:13:39",
            ChangeBy => 1,

            # FAQ dynamic fields
            DynamicField_Text => 'TextValue',
            DynamicField_Multiselect => [1,2,3],

            # attachments
            Attachment_FileID            => 'value',
            Attachment_Filename          => 'value',
            Attachment_Filesize          => 'value',
            Attachment_FilesizeRaw       => 'value',
            Attachment_ContentType       => 'value',
            Attachment_Content           => 'value',
            Attachment_AttachmentContent => 'value', # readable content
            Attachment_Inline            => 'value',
            Attachment_Created           => "2022-08-17 13:13:23",
            Attachment_CreateBy          => 1,
            Attachment_Changed           => "2022-08-17 13:13:39",
            Attachment_ChangeBy          => 1,

            # attachment ingest plugin field, use to search in attachment content as pdf, ppt, xls etc.
            Attachment_AttachmentContent => {
                Operator => 'FULLTEXT', Value => {
                    OperatorQuery => 'AND',
                    Text => 'value',
                }
            },

            # permission parameters
            # required either group id or UserID
            GroupID => [1,2,3],
            # when combined witch UserID, there is used "OR" match
            # meaning groups for specified user including groups from
            # "GroupID" will match FAQs
            UserID => 1, # no operators support
            Permissions => 'ro' # no operators support, by default "ro" value will be used
                                # permissions for user, therefore should be combined with UserID param

            # additionally there is a possibility to pass names for fields below
            # always pass them in an array or scalar
            # can be combined with its IDs alternative (will match
            # by "AND" operator as any other fields)
            # operators syntax is not supported on those fields
            CategoryShortName          => ['CategoryShortName1'],
            Language        => ['en'],
            Valid         => ['valid', 'invalid'],
            State         => ['State1', 'State2'],

            # fulltext parameter can be used to search by properties specified
            # in sysconfig "SearchEngine::ES::FAQSearchFields###Fulltext"
            Fulltext      => 'elasticsearch',
            #    OR
            Fulltext      => ['elasticsearch', 'kibana'],
            #    OR
            Fulltext      => {
                Fields => {             # or specify fields yourselves
                   FAQ => ['Name', 'Title'],
                   Attachment => ['Filename', 'Filesize']
                },
                Highlight => ['FAQ_Name', 'FAQ_Title', 'Attachment_Filename'],
                Text => ['elasticsearch', 'kibana'],
                QueryOperator => 'AND', # determine if all words from specified
                                        # value needs to match
                                        # optional, default: "AND"
                                        # possible: "OR" - only single word needs to match
                                        #           "AND" - all words needs to match
                                        # example: 'elasticsearch is super fast'
                                        # each of those are separate words, decide here if
                                        # all of them needs to be matched or only one
                StatementOperator => 'OR', # determine if all values from specified ones
                                           # in an array needs to match
                                           # optional, default: "OR"
                                           # possible: "OR" - single value from an array needs to match
                                           #           "AND" - all values from an array needs to match
                                           # use only when specifying multiple values to search by
                                           # example: ['elasticsearch is super fast', 'sql search is slower for fulltext search']
                                           # decide here if both of these values needs to matched or only one
            }
        },
        Fields => [['FAQ_FAQID', 'FAQ_FAQNumber']] # specify field from field mapping
            # to get:
            # - FAQ fields (all): [['FAQ_*']]
            # - FAQ field (specified): [['FAQ_FAQID', 'FAQ_Title']]
            # - FAQ dynamic fields (all): [['FAQ_DynamicField_*']]
            # - FAQ dynamic fields (specified): [['FAQ_DynamicField_multiselect', 'FAQ_DynamicField_dropdown']]
            # - FAQ "GroupID" field (external field): [['FAQ_GroupID']]
            # - attachment (all standard fields + AttachmentContent): [['Attachment_*']]
            # - attachment (specified): [['Attachment_ContentID']]
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $Data = $Self->PreSearch(%Param);
    return $Self->SearchEmptyResponse(%Param) if !IsHashRefWithData($Data);
    return $Self->ExecuteSearch( %{$Data} );
}

=head2 ExecuteSearch()

perform actual search

    my $Result = $SearchFAQESObject->ExecuteSearch(
        %Param,
        Limit          => $Limit,
        Fields         => $Fields,
        QueryParams    => $Param{QueryParams},
        SortBy         => $SortBy,
        OrderBy        => $OrderBy,
        RealIndexName  => $Self->{Config}->{IndexRealName},
        ResultType     => $ValidResultType,
    );

=cut

sub ExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    if (
        !$Param{NoPermissions}
        &&
        !$Param{QueryParams}->{UserID} &&
        !IsArrayRefWithData( $Param{QueryParams}->{GroupID} )
        )
    {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Either UserID or GroupID is required for FAQ search!"
        );
        return $Self->SearchEmptyResponse(%Param);
    }

    if ( $Param{UseSQLSearch} || $SearchObject->{Fallback} ) {
        return $Self->FallbackExecuteSearch(%Param);
    }

    my $IndexName = $Self->{Config}->{IndexName};

    my $OperatorModule   = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");
    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$IndexName");
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');

    my $QueryParams = $Param{QueryParams};
    my $Fulltext    = delete $QueryParams->{Fulltext};

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams   => $QueryParams,
        NoPermissions => $Param{NoPermissions},
        QueryFor      => 'Engine',
        Strict        => 1,
    );

    return $Self->SearchEmptyResponse(%Param)
        if ref $SearchParams eq 'HASH' && $SearchParams->{Error};

    my $SegregatedQueryParams;

    # segregate search params
    for my $SearchParam ( sort keys %{$SearchParams} ) {
        if ( $SearchParam =~ m{^Attachment_(.+)} ) {
            $SegregatedQueryParams->{Attachments}->{$1} =
                $SearchParams->{$SearchParam};
        }
        else {
            $SegregatedQueryParams->{FAQ}->{$SearchParam} = $SearchParams->{$SearchParam};
        }
    }

    my $Fields           = $Param{Fields}              || {};
    my $FAQFields        = $Fields->{FAQ}              || {};
    my $FAQDynamicFields = $Fields->{FAQ_DynamicField} || {};
    my $AttachmentFields = $Fields->{Attachment}       || {};

    my %FAQFields        = ( %{$FAQFields}, %{$FAQDynamicFields} );
    my %AttachmentFields = %{$AttachmentFields};

    # build standard faq query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        Fields      => \%FAQFields,
        QueryParams => $SegregatedQueryParams->{FAQ},
        Object      => $IndexName,
        _Source     => 1,
    );

    my $FulltextQuery = $Self->DefaultFulltextQueryBuild(
        Query               => $Query,
        AppendIntoQuery     => 1,
        EngineObject        => $Param{EngineObject},
        MappingObject       => $Param{MappingObject},
        Fulltext            => $Fulltext,
        EntitiesPathMapping => {
            FAQ => {
                Path             => '',
                FieldBuildPrefix => '',
                Nested           => 0,
            },
            Attachment => {
                Path             => 'Attachments',
                FieldBuildPrefix => 'Attachments.',
                Nested           => 1,
            },
        },
        DefaultFields => $ConfigObject->Get('SearchEngine::ES::FAQSearchFields')->{Fulltext},
        Simple        => 0,
    );

    return $Self->SearchEmptyResponse(%Param) if !$FulltextQuery->{Success};

    my $RetrieveHighlightData = IsHashRefWithData( $Query->{Body}->{highlight} )
        && IsArrayRefWithData( $Query->{Body}->{highlight}->{fields} );

    my $AttachmentSearchParams = $SegregatedQueryParams->{Attachments};

    my $AttachmentNestedQuery = {
        nested => {
            path => 'Attachments',
        }
    };

    # check if there were any attachments passed
    # in "Fields" param, also check if result type ne COUNT to do not break query
    if ( keys %AttachmentFields && $Param{ResultType} ne "COUNT" ) {

        # prepare query part for children fields to retrieve
        for my $AttachmentField ( sort keys %AttachmentFields ) {
            push @{ $Query->{Body}->{_source} },
                'Attachments.' . $AttachmentField;
        }
    }

    # build and append attachment query if needed
    if ( IsHashRefWithData($AttachmentSearchParams) ) {
        ATTACHMENT:
        for my $AttachmentField ( sort keys %{$AttachmentSearchParams} ) {
            for my $OperatorData ( @{ $AttachmentSearchParams->{$AttachmentField}->{Query} } ) {
                my $OperatorValue           = $OperatorData->{Value};
                my $AttachmentFieldForQuery = 'Attachments.' . $AttachmentField;

                # build query
                my $Result = $OperatorModule->OperatorQueryGet(
                    Field      => $AttachmentFieldForQuery,
                    ReturnType => $OperatorData->{ReturnType},
                    Value      => $OperatorValue,
                    Operator   => $OperatorData->{Operator},
                    FieldType  => $OperatorData->{Type},
                    Object     => $IndexName,
                );

                my $AttachmentQuery = $Result->{Query};

                # append query
                push @{ $AttachmentNestedQuery->{nested}->{query}->{bool}->{ $Result->{Section} } }, $AttachmentQuery
                    if !$Result->{Ignore};
            }
        }
    }

    my $NestedAttachmentQueryBuilt = IsHashRefWithData( $AttachmentNestedQuery->{nested}->{query} ) ? 1 : 0;

    # apply nested attachment query if it was built
    push @{ $Query->{Body}->{query}->{bool}->{must} }, $AttachmentNestedQuery if $NestedAttachmentQueryBuilt;

    # execute query
    my $Response = $Param{EngineObject}->QueryExecute(
        Query         => $Query,
        Operation     => 'Search',
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{GlobalConfig},
        Silent        => $Param{Silent},
    );

    # format query
    my $FormattedResult = $SearchObject->SearchFormat(
        %Param,
        Fields     => \%FAQFields,
        Result     => $Response,
        IndexName  => $IndexName,
        ResultType => $Param{ResultType} || 'ARRAY',
        QueryData  => {
            Query                 => $Query,
            RetrieveHighlightData => $RetrieveHighlightData,
        },
    );

    return $FormattedResult;
}

=head2 FallbackExecuteSearch()

execute fallback for searching FAQs

notice: fall-back is not supported

    my $FunctionResult = $SearchFAQESObject->FallbackExecuteSearch(
        %Params,
    );

=cut

sub FallbackExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    return $Self->SearchEmptyResponse(%Param)
        if !$Param{ResultType} || ( $Param{ResultType} && $Param{ResultType} ne 'COUNT' ) && !$Param{Force};

    my $Result = {
        FAQ => $Self->Fallback( %Param, Fields => $Param{Fields}->{FAQ} ) // []
    };

    # format reponse per index
    my $FormattedResult = $SearchObject->SearchFormat(
        Result     => $Result,
        Config     => $Param{GlobalConfig},
        IndexName  => $Self->{Config}->{IndexName},
        ResultType => $Param{ResultType} || 'ARRAY',
        Fallback   => 1,
        Silent     => $Param{Silent},
        Fields     => $Param{Fields}->{FAQ},
    );

    return $FormattedResult || { FAQ => [] };
}

sub ObjectIndexAdd() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function            => $Param{Function} || '_ObjectIndexAddAction',
        SetEmptyAttachments => 1,
        NoPermissions       => 1,
        IndexDynamicFields  => 1,
        IndexBaseData       => 1,
        IndexAttachments    => $Self->{Config}->{Settings}->{IndexAttachments},
        RunPipeline         => $Self->{Config}->{Settings}->{IndexAttachments},
    );
}

sub ObjectIndexSet() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function            => '_ObjectIndexSetAction',
        SetEmptyAttachments => 1,
        NoPermissions       => 1,
        IndexDynamicFields  => 1,
        IndexBaseData       => 1,
        IndexAttachments    => $Self->{Config}->{Settings}->{IndexAttachments},
        RunPipeline         => $Self->{Config}->{Settings}->{IndexAttachments},
    );
}

=head2 ObjectIndexUpdate()

update object faq or/and attachment, additionally execute custom function if needed

    my $Success = $SearchObject->ObjectIndexUpdate(
        Index    => 'FAQ',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)
        # or
        QueryParams => { # do not combine QueryParams with AddAttachment/DeleteAttachment
                         # this is mainly used to execute CustomFunctions or index base data
            FAQID => [1,2,3],
        },

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]

        UpdateFAQ        => 1, # base FAQ properties with dynamic fields
        AddAttachment    => [1,2,3], # add FAQ nested attachments
        DeleteAttachment => [4,5,6], # delete FAQ nested attachments

        # perform custom handling
        CustomFunction => {
            Name => 'ObjectIndexUpdateGroupID',
            Params => {
                NewGroupID => $NewGroupID,
            }
        },
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $Success   = 1;
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $AddOrDeleteAttachmentAction = $Param{AddAttachment} || $Param{DeleteAttachment};

    if ($AddOrDeleteAttachmentAction) {
        if ( $Param{QueryParams} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "QueryParams parameter not supported!",
            );
        }
        elsif ( IsArrayRefWithData( $Param{ObjectID} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Multiple ObjectID parameter not supported!",
            );
        }
    }

    # update base FAQ properties
    # or delete specified FAQ attachments
    # or add specified FAQ attachments
    my $IndexBaseData = $Param{UpdateFAQ};
    my $RunPipeline   = $Self->{Config}->{Settings}->{IndexAttachments} && (
        $AddOrDeleteAttachmentAction
    ) ? 1 : 0;

    $Success = $Self->ObjectIndexGeneric(
        %Param,
        Function                 => '_ObjectIndexUpdateAction',
        SetEmptyAttachments      => 0,
        NoPermissions            => 1,
        IndexDynamicFields       => $IndexBaseData,
        IndexBaseData            => $IndexBaseData,
        IndexAttachments         => 0,
        IndexAttachmentsSeparate => $RunPipeline,
        RunPipeline              => $RunPipeline,
    ) if $AddOrDeleteAttachmentAction || $IndexBaseData;

    # custom handling of update
    if ( IsHashRefWithData( $Param{CustomFunction} ) ) {
        $Success = $Self->CustomFunction(%Param) if $Success;
    }

    return $Success;
}

=head2 ObjectIndexUpdateGroupID()

update FAQs group ids

    my $Success = $SearchFAQESObject->ObjectIndexUpdateGroupID(
        Params => {
            NewGroupID => [1,2,3],
        }
        ConnectObject => $ConnectObject,
        EngineObject => $EngineObject,
        MappingObject => $MappingObject,
    );

=cut

sub ObjectIndexUpdateGroupID {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw( ConnectObject EngineObject MappingObject)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !$Param{Params}->{NewGroupID} || ref $Param{Params}->{NewGroupID} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need 'NewGroupID'!"
        );
        return;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams   => $Param{QueryParams},
        NoPermissions => 1,
        QueryFor      => 'Engine',
    );

    # build body
    my %Body = $Param{MappingObject}->_BuildQueryBodyFromParams(
        QueryParams => $SearchParams,
        Object      => $Self->{Config}->{IndexName},
    );

    my $Query = {
        Method => 'POST',
        Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
        Body   => {
            %Body,
            script => {
                params => {
                    value => $Param{Params}->{NewGroupID},
                },
                source => "ctx._source.GroupID = params.value",
            },
        },
        QS => {
            wait_for_completion => 'true',
            timeout             => '30s',
            refresh             => 'true',
        }
    };

    my $Response = $Param{EngineObject}->QueryExecute(
        Operation     => 'Generic',
        Query         => $Query,
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->ResponseIsSuccess(
        Response => $Response,
    );
}

=head2 ObjectIndexUpdateDFChanged()

update FAQs that contains specified dynamic field

    my $Success = $SearchFAQESObject->ObjectIndexUpdateDFChanged(
        ConnectObject => $ConnectObject,
        EngineObject => $EngineObject,
        MappingObject => $MappingObject,
        Params => {
            DynamicField => {
                ObjectType => $ObjectType,
                Name       => $OldDFName,
                NewName    => $Param{Data}->{NewData}->{Name},
                Event      => 'NameChange', # also possible: 'Remove'
            }
        }
    );

=cut

sub ObjectIndexUpdateDFChanged {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw( ConnectObject EngineObject MappingObject)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !$Param{Params}->{DynamicField} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need 'DynamicField' inside Params hash!"
        );
        return;
    }

    NEEDED:
    for my $Needed (qw(ObjectType Name Event)) {

        next NEEDED if defined $Param{Params}->{DynamicField}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed inside Params->{DynamicField} hash!",
        );
        return;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");
    my %Body;

    my $DynamicFieldType  = $Param{Params}->{DynamicField}->{ObjectType};
    my $DynamicFieldName  = $Param{Params}->{DynamicField}->{Name};
    my $DynamicFieldEvent = $Param{Params}->{DynamicField}->{Event};

    my $NewName = $Param{Params}->{DynamicField}->{NewName} || '';

    # only FAQ dynamic fields
    return if !$DynamicFieldType || $DynamicFieldType ne 'FAQ';

    # build body
    %Body = (
        query => {
            bool => {
                should => [
                    {
                        exists =>
                            {
                            field => "DynamicField_$DynamicFieldName"
                            },
                    },
                    {
                        exists =>
                            {
                            field => "DynamicField_"
                                . $NewName,
                            }
                    }
                ]
            }
        }
    );

    my $Source;

    # remove dynamic field
    if ( $DynamicFieldEvent eq 'Remove' ) {
        $Source = "
            ctx._source.remove('DynamicField_$DynamicFieldName');
        ";
    }

    # change name of dynamic field
    elsif ( $DynamicFieldEvent eq 'NameChange' ) {
        if ( !$Param{Params}->{DynamicField}->{NewName} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'NewName' is needed inside Params->{DynamicField} hash!",
            );
            return;
        }

        my $NewDFName = $Param{Params}->{DynamicField}->{NewName};
        my $OldDFName = $DynamicFieldName;

        if ( $DynamicFieldType eq 'FAQ' ) {
            $Source = "
                if(ctx._source.DynamicField_$OldDFName != null){
                    if(ctx._source.DynamicField_$NewDFName == null){
                        ctx._source.put('DynamicField_$NewDFName', ctx._source.DynamicField_$OldDFName);
                    }
                    ctx._source.remove('DynamicField_$OldDFName');
                }
            ";
        }
    }
    else {
        return;
    }

    my $Query = {
        Method => 'POST',
        Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
        Body   => {
            %Body,
            script => {
                source => $Source,
            },
        },

        QS => {
            wait_for_completion => 'true',
            timeout             => '30s',
            refresh             => 'true',
        }
    };

    my $Response = $Param{EngineObject}->QueryExecute(
        Operation     => 'Generic',
        Query         => $Query,
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->ResponseIsSuccess(
        Response => $Response,
    );
}

=head2 ObjectIndexGeneric()

search for FAQs with restrictions, then perform specified operation

    my $Success = $SearchFAQESObject->ObjectIndexGeneric(
        Index    => 'FAQ',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            FAQID => [1,2,3],
        },

        Function => 'FunctionName' # function callback name
                                   # to which the object data
                                   # will be sent
        NoPermissions => 1 # optional, skip permissions check
    );

=cut

sub ObjectIndexGeneric {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $Function     = $Param{Function};

    return if !$Function;
    return if !$Self->_BaseCheckIndexOperation(%Param);

    my $Identifier = $Self->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    my $DataCount;
    my $SQLDataIDs;

    # FAQ id limit to process at once
    my $IDLimit = 100_00;

    # additional limit for single request
    my $ReindexationSettings = $ConfigObject->Get('SearchEngine::Reindexation')->{Settings};
    my $ReindexationStep     = $ReindexationSettings->{ReindexationStep} // 10;

    # success is hard to identify for that many objects
    # simply return 1 when 100% of data will execute queries
    # correctly, otherwise return 0
    my $Success             = 1;
    my $FAQOffsetMultiplier = 0;

    do {
        my $FAQOffset = $FAQOffsetMultiplier++ * $IDLimit;

        $SQLDataIDs = $Self->ObjectListIDs(
            QueryParams => $QueryParams,
            Fields      => [$Identifier],
            Limit       => $IDLimit,
            Offset      => $FAQOffset,
            SortBy      => $Identifier,
            OrderBy     => 'Down',
        );

        $DataCount = scalar @{$SQLDataIDs};

        if ($DataCount) {

            # no need to apply object count restrictions
            if ( $DataCount <= $ReindexationStep ) {
                my $SQLSearchResult = $Self->SQLObjectSearch(
                    %Param,
                    QueryParams => {
                        $Identifier => $SQLDataIDs,
                    },
                    ResultType          => $Param{SQLSearchResultType} || 'ARRAY',
                    IgnoreBaseData      => !$Param{IndexBaseData},
                    IgnoreAttachments   => !$Param{IndexAttachments},
                    IgnoreDynamicFields => !$Param{IndexDynamicFields},
                    NoPermissions       => $Param{NoPermissions},
                    SetEmptyAttachments => $Param{SetEmptyAttachments},
                    SortBy              => $Identifier,
                    OrderBy             => 'Down',
                );

                my $SuccessLocal = $Self->$Function(
                    %Param,
                    DataToIndex => $SQLSearchResult,
                    FAQIDs      => $SQLDataIDs,
                );

                $Success = $SuccessLocal if $Success && !$SuccessLocal;
            }
            else {
                # restrict data size
                my $IterationCount = ceil( $DataCount / $ReindexationStep );

                # index data in parts
                for my $OffsetMultiplier ( 0 .. $IterationCount - 1 ) {
                    my $Offset          = $OffsetMultiplier * $ReindexationStep;
                    my $SQLSearchResult = $Self->SQLObjectSearch(
                        %Param,
                        QueryParams => {
                            $Identifier => $SQLDataIDs,
                        },
                        ResultType          => $Param{SQLSearchResultType} || 'ARRAY',
                        IgnoreBaseData      => !$Param{IndexBaseData},
                        IgnoreAttachments   => !$Param{IndexAttachments},
                        IgnoreDynamicFields => !$Param{IndexDynamicFields},
                        Offset              => $Offset,
                        Limit               => $ReindexationStep,
                        NoPermissions       => $Param{NoPermissions},
                        SetEmptyAttachments => $Param{SetEmptyAttachments},
                        SortBy              => $Identifier,
                        OrderBy             => 'Down',
                    );

                    my @ObjectDataIDsToProcess = @{$SQLDataIDs}[ $Offset .. ( $Offset + $ReindexationStep - 1 ) ];

                    my $PartSuccess = $Self->$Function(
                        %Param,
                        DataToIndex => $SQLSearchResult,
                        FAQIDs      => \@ObjectDataIDsToProcess,
                    );

                    $Success = $PartSuccess if $Success && !$PartSuccess;
                }
            }

            # run pipeline if needed, but only when indexing attachments
            # as pipeline is only for them to build readable content
            if ( $Param{RunPipeline} && $Self->{Config}->{Settings}->{IndexAttachments} ) {
                $SearchObject->IndexRefresh(
                    Index => $Self->{Config}->{IndexName},
                );

                # run attachment pipeline after indexation
                my $Query = {
                    Method => 'POST',
                    Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
                    Body   => {
                        query => {
                            terms => {
                                $Self->{Config}->{Identifier} => $SQLDataIDs,
                            },
                        },
                    },
                    QS => {
                        pipeline => 'attachment_nested_faq',

                        # pipeline can be timed out on very large data
                        # to prevent it make a task inside
                        # elasticsearch
                        # to be uncommented if the problem will occur
                        # wait_for_completion => 'false', # <- uncomment this line
                    },
                };

                my $Response = $Param{EngineObject}->QueryExecute(
                    Operation     => 'Generic',
                    Query         => $Query,
                    ConnectObject => $Param{ConnectObject},
                );
            }
        }
    } while ( $DataCount == $IDLimit );

    return $Success;
}

=head2 ObjectIndexRemove()

remove object from specified index

    my $Success = $SearchObject->ObjectIndexRemove(
        Index => "FAQ",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            FAQID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },

        NoPermissions => 1 # optional, skip permissions check
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    return $Self->SUPER::ObjectIndexRemove(
        %Param,
        NoPermissions => 1,
    );
}

=head2 IndexMappingSet()

create query for index mapping set operation

    my $Result = $SearchQueryObject->IndexMappingSet(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexMappingSet {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    my $QueryFAQObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::FAQ');

    my $MappingQuery = $QueryFAQObject->IndexMappingSet(
        MappingObject => $Param{MappingObject},
    );

    return if !IsHashRefWithData( $MappingQuery->{Body}->{properties} );

    my $DataTypes = $Param{MappingObject}->MappingDataTypesGet();

    my %FAQAttachmentFields = %{ $Self->{AttachmentFields} };

    # add nested type relation for FAQs
    if ( keys %FAQAttachmentFields ) {
        $MappingQuery->{Body}->{properties}->{Attachments} = {
            type       => 'nested',
            properties => {}
        };

        for my $AttachmentFieldName ( sort keys %FAQAttachmentFields ) {
            $MappingQuery->{Body}->{properties}->{Attachments}->{properties}->{$AttachmentFieldName}
                = $DataTypes->{ $FAQAttachmentFields{$AttachmentFieldName}->{Type} };
        }
    }

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Query         => $MappingQuery,
        Operation     => "IndexMappingSet",
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->IndexMappingSetFormat(
        %Param,
        Response => $Response,
        Config   => $Param{Config},
    );
}

=head2 SQLObjectSearch()

search in sql database for objects index related

    my $Result = $SearchFAQESObject->SQLObjectSearch(
        QueryParams => {
            FAQID => 1,
        },
        Fields      => ['FAQID', 'SLAID'] # optional, returns all
                                             # fields if not specified
        SortBy      => $IdentifierSQL,
        OrderBy     => "Down",  # possible: "Down", "Up",
        ResultType  => $ResultType,
        Limit       => 10,
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $EncodeObject              = $Kernel::OM->Get('Kernel::System::Encode');
    my $GroupObject               = $Kernel::OM->Get('Kernel::System::Group');
    my $DBObject                  = $Kernel::OM->Get('Kernel::System::DB');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $FAQObject                 = $Kernel::OM->Get('Kernel::System::FAQ');
    my $LogObject                 = $Kernel::OM->Get('Kernel::System::Log');

    return {
        Success => 0,
        Data    => [],
    } if !$Param{NoPermissions};

    my $QueryParams = $Param{QueryParams};
    my $Fields      = $Param{Fields};
    my $GroupField;

    if ( $Param{IgnoreBaseData} ) {
        if ( !$Param{NoPermissions} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Can't ignore base data without NoPermissions parameter!",
            );
            return {
                Success => 0,
                Data    => [],
            };
        }
        $Fields = [ $Self->{Config}->{Identifier} ];
    }

    # fields passed as hash needs to be
    # converted into array due to further calculations
    if ( IsHashRefWithData($Fields) ) {
        my %Fields = %{ $Param{Fields} };
        undef $Fields;
        @{$Fields} = keys %{ $Param{Fields} };
    }
    elsif ( !$Fields || !IsArrayRefWithData($Fields) ) {

        # no fields specified will return response with standard fields
        # plus denormalized group id
        @{$Fields} = keys %{ $Self->{Fields} };
        $GroupField = 'GroupID';
    }

    my @GroupQueryParam;

    # delete groupid, userid, permissions from queryparams/fields
    # as those are not present in the FAQ table
    # support them after standard sql search
    if ( IsArrayRefWithData( $QueryParams->{GroupID} ) ) {
        my $GroupIDs = delete $QueryParams->{GroupID};
        @GroupQueryParam = @{$GroupIDs};
    }
    elsif ( $QueryParams->{GroupID} ) {
        delete $QueryParams->{GroupID};
    }
    my $UserIDQueryParam      = delete $QueryParams->{UserID};
    my $PermissionsQueryParam = delete $QueryParams->{Permissions};

    if ( !$GroupField ) {
        FIELDS:
        for ( my $i = 0; $i < scalar @{$Fields}; $i++ ) {
            if ( $Fields->[$i] eq 'GroupID' ) {
                $GroupField = delete $Fields->[$i];
                @{$Fields} = grep {$_} @{$Fields};
                last FIELDS;
            }
        }
    }

    # perform default sql object search
    my $SQLSearchResult = $Self->SUPER::SQLObjectSearch(
        %Param,
        QueryParams => $QueryParams,
        Fields      => $Fields,
    );

    return $SQLSearchResult if !$SQLSearchResult->{Success};
    return $SQLSearchResult if !IsArrayRefWithData( $SQLSearchResult->{Data} );

    if ( !$Param{IgnoreDynamicFields} || !$Param{IgnoreAttachments} ) {

        # get all dynamic fields for the object type FAQ
        my $FAQDynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
            ObjectType => 'FAQ'
        );

        FAQ:
        for my $FAQ ( @{ $SQLSearchResult->{Data} } ) {

            if ( !$Param{IgnoreDynamicFields} ) {
                DYNAMICFIELDCONFIG:
                for my $DynamicFieldConfig ( @{$FAQDynamicFieldList} ) {

                    # get the current value for each dynamic field
                    my $Value = $DynamicFieldBackendObject->ValueGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        ObjectID           => $FAQ->{ItemID},
                    );

                    $FAQ->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
                }
            }

            my @Attachments;

            if ( !$Param{IgnoreAttachments} ) {

                $FAQ->{AttachmentStorageTemp} = [];

                my @Attachments = $Self->_AttachmentsGet(
                    ItemID     => $FAQ->{ItemID},
                    ShowInline => 1,
                    UserID     => 1,
                );

                $FAQ->{Attachments} = \@Attachments;
                push @{ $FAQ->{AttachmentStorageTemp} }, @Attachments;
                $FAQ->{AttachmentStorageClearTemp} = {};
            }
            elsif ( $Param{SetEmptyAttachments} ) {
                $FAQ->{Attachments} = [];
            }
        }
    }

    # support user id, group id, permissions params
    if ( $GroupField || scalar(@GroupQueryParam) || $UserIDQueryParam ) {
        my @GroupFilteredResult;

        # support permissions
        if ($UserIDQueryParam) {

            # get users groups
            my %GroupList = $GroupObject->PermissionUserGet(
                UserID => $UserIDQueryParam,
                Type   => $PermissionsQueryParam || 'ro',
            );

            # push user groups on the same array as groups from "GroupID" parameter
            push @GroupQueryParam, keys %GroupList;
        }

        my $AllCategoryHashArray;
        my $AllCategory = $FAQObject->CategoryGroupGetAll(
            UserID => 1,
        );
        if ( scalar @GroupQueryParam || $GroupField ) {
            for my $CategoryID ( sort keys %{$AllCategory} ) {
                $AllCategoryHashArray->{$CategoryID} = [ sort keys %{ $AllCategory->{$CategoryID} } ];
            }
        }

        my $NoPermissionCheck = !scalar @GroupQueryParam;

        ROW:
        for my $Row ( @{ $SQLSearchResult->{Data} } ) {

            my $CategoryID = $Row->{CategoryID};

            my $PermissionOk        = $NoPermissionCheck;
            my $CategoryPermissions = $AllCategory->{$CategoryID};

            if ( !$PermissionOk ) {
                my $GroupIDs;

                GROUP:
                for my $GroupID (@GroupQueryParam) {
                    if ( $CategoryPermissions->{$GroupID} ) {
                        $PermissionOk = 1;
                        last GROUP;
                    }
                }
            }

            # check if FAQ exists in specified groups of user/group params
            if ($PermissionOk) {

                # additionally append GroupID to the response
                if ($GroupField) {
                    $Row->{GroupID} = $AllCategoryHashArray->{$CategoryID};
                }
                push @GroupFilteredResult, $Row;
            }
        }
        return {
            Success => $SQLSearchResult->{Success},
            Data    => \@GroupFilteredResult,
        };
    }
    return $SQLSearchResult;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchFAQESObject->ValidFieldsPrepare(
        Fields      => $Fields, # optional
        Object      => $ObjectName,
        QueryParams => $QueryParams,
    );

=cut

sub ValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Object)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return ();
    }

    my $SearchQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Object}");

    my $Fields         = $Self->{Fields};
    my $ExternalFields = $Self->{ExternalFields};
    my %ValidFields;

    # when no fields are specified use all standard fields
    # (without dynamic fields)
    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        %ValidFields = (
            FAQ => { %{$Fields}, %{$ExternalFields} }
        );

        return $Self->_PostValidFieldsPrepare(
            ValidFields => \%ValidFields,
            QueryParams => $Param{QueryParams},
        );
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    my $AllAttachmentFields = $Self->{AttachmentFields};

    PARAMFIELD:
    for my $ParamField ( @{ $Param{Fields} } ) {

        # get information about field types if field
        # matches specified regexp
        if ( $ParamField =~ m{\AFAQ_DynamicField_(.+)} ) {
            my $DynamicFieldName = $1;

            if ( $DynamicFieldName eq '*' ) {
                my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
                    ObjectType => 'FAQ',
                );

                for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next PARAMFIELD if !$Info->{ColumnName};
                    $ValidFields{'FAQ_DynamicField'}->{ $Info->{ColumnName} } = $Info;
                }
            }
            else {
                # get single dynamic field config
                my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                    Name => $DynamicFieldName,
                );

                next PARAMFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next PARAMFIELD if 'FAQ' ne $DynamicFieldConfig->{ObjectType};

                if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        ObjectType         => 'FAQ',
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next PARAMFIELD if !$Info->{ColumnName};
                    $ValidFields{'FAQ_DynamicField'}->{ $Info->{ColumnName} } = $Info;
                }
            }
        }

        # apply "FAQ" fields
        elsif ( $ParamField =~ m{\AFAQ_(.+)\z} ) {
            my $FAQField = $1;

            # get single "FAQ" field
            if ( $Fields->{$FAQField} ) {
                $ValidFields{FAQ}->{$FAQField} = $Fields->{$FAQField};
            }

            # get single field from external fields
            # that is for example "GroupID"
            elsif ( $ExternalFields->{$FAQField} ) {
                $ValidFields{FAQ}->{$FAQField} = $ExternalFields->{$FAQField};
            }

            # get all "FAQ" fields
            elsif ( $FAQField eq '*' ) {
                my $FAQFields = $ValidFields{FAQ} // {};
                %{ $ValidFields{FAQ} } = ( %{$Fields}, %{$ExternalFields}, %{$FAQFields} );
            }
        }

        # apply "Attachment" fields
        elsif ( $ParamField =~ m{^Attachment_(.+)$} && $Self->{Config}->{Settings}->{IndexAttachments} ) {
            my $AttachmentField = $1;

            if ( $AttachmentField && $AttachmentField eq '*' ) {
                for my $AttachmentFieldName ( sort keys %{$AllAttachmentFields} ) {
                    $ValidFields{Attachment}->{$AttachmentFieldName} = $AllAttachmentFields->{$AttachmentFieldName};
                }
            }
            else {
                $ValidFields{Attachment}->{$AttachmentField} = $AllAttachmentFields->{$AttachmentField};
            }
        }
    }

    return $Self->_PostValidFieldsPrepare(
        ValidFields => \%ValidFields,
        QueryParams => $Param{QueryParams},
    );
}

=head2 ObjectListIDs()

return all sql data of object ids

    my $ResultIDs = $SearchFAQObject->ObjectListIDs();

=cut

sub ObjectListIDs {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Self->{Config}->{IndexName}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    # search for all objects
    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams         => $Param{QueryParams} || {},
        Fields              => [$Identifier],
        OrderBy             => $Param{OrderBy},
        SortBy              => $Param{SortBy} // $Identifier,
        ResultType          => $Param{ResultType} || 'ARRAY_SIMPLE',
        Limit               => $Param{Limit},
        Offset              => $Param{Offset},
        IgnoreAttachments   => 1,
        IgnoreDynamicFields => 1,
        NoPermissions       => 1,
    );

    my @Result;
    if ( $SQLSearchResult->{Success} ) {
        return $SQLSearchResult->{Data};
    }

    return \@Result;
}

=head2 ObjectIndexQueueUpdateRule()

apply index object update rule for queries

    my $Success = $SearchBaseObject->ObjectIndexQueueUpdateRule(
        Queue      => $Queue,
        QueueToAdd => $QueueToAdd,
    );

=cut

sub ObjectIndexQueueUpdateRule {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    return if !IsHashRefWithData( $Param{QueueToAdd} );

    my $ObjectIDQueueToAdd    = $Param{QueueToAdd}->{ObjectID};
    my $QueryParamsQueueToAdd = $Param{QueueToAdd}->{QueryParams};

    # check if ObjectIndexUpdate by object id is to be queued
    if ($ObjectIDQueueToAdd) {
        my $QueuedOperation = $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1];
        if ($QueuedOperation) {

            # identify what operation was already queued
            my $PrevQueuedOperationName = $QueuedOperation->{Operation};

            # add overwrites update
            if ( $PrevQueuedOperationName eq 'ObjectIndexAdd' ) {
                return;
            }

            elsif ( $PrevQueuedOperationName eq 'ObjectIndexUpdate' ) {
                my $Changed;
                my $UpdateFAQQueuedBefore = $QueuedOperation->{Data}->{UpdateFAQ};
                my $UpdateFAQQueuedNow    = $Param{QueueToAdd}->{Data}->{UpdateFAQ};

                if ( $UpdateFAQQueuedNow && !$UpdateFAQQueuedBefore ) {
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{UpdateFAQ} = $UpdateFAQQueuedNow;
                    $Changed = 1;
                }

                my %AttachmentQueue = (
                    Add => {
                        Actual => ref( $QueuedOperation->{Data}->{AddAttachment} ) eq 'ARRAY'
                        ? { map { $_ => 1 } @{ $QueuedOperation->{Data}->{AddAttachment} } }
                        : {},
                        Now => ref( $Param{QueueToAdd}->{Data}->{AddAttachment} ) eq 'ARRAY'
                        ? { map { $_ => 1 } @{ $Param{QueueToAdd}->{Data}->{AddAttachment} } }
                        : {},
                    },
                    Delete => {
                        Actual => ref( $QueuedOperation->{Data}->{DeleteAttachment} ) eq 'ARRAY'
                        ? { map { $_ => 1 } @{ $QueuedOperation->{Data}->{DeleteAttachment} } }
                        : {},
                        Now => ref( $Param{QueueToAdd}->{Data}->{DeleteAttachment} ) eq 'ARRAY'
                        ? { map { $_ => 1 } @{ $Param{QueueToAdd}->{Data}->{DeleteAttachment} } }
                        : {},
                    }
                );

                if ( keys( %{ $AttachmentQueue{Add}->{Now} } ) || ( keys %{ $AttachmentQueue{Delete}->{Now} } ) ) {

                    # case added now
                    ATTACHMENT:
                    for my $AttachmentID ( sort keys %{ $AttachmentQueue{Add}->{Now} } ) {

                        # already exists
                        next ATTACHMENT if $AttachmentQueue{Add}->{Actual}->{$AttachmentID};

                        # queue to add
                        $AttachmentQueue{Add}->{Actual}->{$AttachmentID} = 1;
                        $Changed = 1;
                    }

                    # case deleted now
                    ATTACHMENT:
                    for my $AttachmentID ( sort keys %{ $AttachmentQueue{Delete}->{Now} } ) {

                        # already exists
                        next ATTACHMENT if $AttachmentQueue{Delete}->{Actual}->{$AttachmentID};

                        # check if attachment to be queued to delete is added to add action
                        my $AttachmentAddExists = $AttachmentQueue{Add}->{Actual}->{$AttachmentID};

                        # attachment queued to be added, then to be deleted
                        # clear both queue actions as doing nothing is equal to add, then delete an attachment
                        if ($AttachmentAddExists) {

                            # delete attachment from add queue
                            delete $AttachmentQueue{Add}->{Actual}->{$AttachmentID};

                            # delete attachment from delete queue
                            delete $AttachmentQueue{Delete}->{Actual}->{$AttachmentID};
                            $Changed = 1;
                            next ATTACHMENT;
                        }

                        # queue attachment to delete
                        $AttachmentQueue{Delete}->{Actual}->{$AttachmentID} = 1;
                        $Changed = 1;
                    }
                }

                # attachment queue was changed in some way
                if ($Changed) {
                    my @AttachmentsToQueueToAdd    = sort keys %{ $AttachmentQueue{Add}->{Actual} };
                    my @AttachmentsToQueueToDelete = sort keys %{ $AttachmentQueue{Delete}->{Actual} };

                    # update queue
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{AddAttachment}
                        = \@AttachmentsToQueueToAdd;
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{DeleteAttachment}
                        = \@AttachmentsToQueueToDelete;

                    return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                        %{ $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1] },
                        ID => $QueuedOperation->{ID},
                    );
                }

                return;
            }

            # set overwrites update
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexSet' ) {
                return;
            }

            # should never be a case in the system, don't allow it
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexRemove' ) {
                return;
            }
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
            );
        }
    }

    # check if ObjectIndexUpdate by query params is to be queued
    elsif ($QueryParamsQueueToAdd) {

        my $Context = $Param{QueueToAdd}->{Context};
        if ( !$Context ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'Context' inside 'QueueToAdd' hash is needed!",
            );
            return;
        }

        my $QueuedOperation = $Param{Queue}->{QueryParams}->{$Context}->[-1];

        if ($QueuedOperation) {
            return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                ID    => $QueuedOperation->{ID},
                Order => $Param{Order},
            );
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
                Order => $Param{Order},
            );
        }
    }
    else {
        return;
    }

    return;
}

=head2 IndexBaseCheck()

Checks index for specific base conditions to determine if it can be used.

    my $Result = $SearchFAQESObject->IndexBaseCheck();

=cut

sub IndexBaseCheck {
    my ( $Self, %Param ) = @_;

    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $ExampleFAQConfig = $ConfigObject->Get("FAQ::Agent::StateTypes");

    return {
        Success => 1,
    } if defined $ExampleFAQConfig;

    return {
        Success => 0,
        Message => $Self->MessageFAQNotInstalled(),
    };
}

=head2 MessageFAQNotInstalled()

return message about not installed faq package

    my $Message = $SearchFAQESObject->MessageFAQNotInstalled();

=cut

sub MessageFAQNotInstalled {
    my ( $Self, %Param ) = @_;

    return 'FAQ index needs FAQ package to be installed!';
}

=head2 _PostValidFieldsPrepare()

set fields return type if not specified

    my %Fields = $SearchFAQESObject->_PostValidFieldsPrepare(
        ValidFields => $ValidFields,
    );

=cut

sub _PostValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    return () if !IsHashRefWithData( $Param{ValidFields} );

    my %ValidFields = %{ $Param{ValidFields} };

    for my $Type (qw(FAQ Attachment)) {
        for my $Field ( sort keys %ValidFields ) {
            if ( $ValidFields{$Type}->{$Field} ) {
                $ValidFields{$Type}->{$Field}->{ReturnType} = 'SCALAR'
                    if !$ValidFields{$Type}->{$Field}->{ReturnType};
            }
        }
    }

    return %ValidFields;
}

sub _ObjectIndexAddAction {
    my ( $Self, %Param ) = @_;

    return if !$Param{FAQIDs};
    return $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexAdd',
    );
}

sub _ObjectIndexUpdateAction {
    my ( $Self, %Param ) = @_;

    return if !$Param{FAQIDs};

    my $DataToIndex = $Param{DataToIndex};
    my $Success;

    if ( $Param{IndexAttachmentsSeparate} ) {
        my $FAQID = $Param{DataToIndex}->{Data}->[0]->{ItemID};

        $Success = $Self->_AttachmentsIndex(
            %Param,
            ItemID => $FAQID,
        ) if $FAQID;
    }

    # index standard properties
    $Success = $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function    => 'ObjectIndexUpdate',
        DataToIndex => $DataToIndex,
    ) if $Param{IndexBaseData} || $Param{IndexDynamicFields};

    return $Success;
}

sub _ObjectIndexSetAction {
    my ( $Self, %Param ) = @_;

    return if !$Param{FAQIDs};
    return $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexSet',
    );
}

=head2 _AttachmentsIndex()

add or delete specified attachment ids for faq

    my $Success = $SearchFAQESObject->_AttachmentsIndex(
        ItemID            => 1,
        AddAttachment    => [1,2,3],
        DeleteAttachment => [4,5,6],
    );

=cut

sub _AttachmentsIndex {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(ItemID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    return 1 if !IsArrayRefWithData( $Param{AddAttachment} ) && !IsArrayRefWithData( $Param{DeleteAttachment} );
    my $ItemID = $Param{ItemID};

    my @AttachmentsToAdd;
    my $AttachmentsToDelete = $Param{DeleteAttachment};

    my $QuerySourceBase = "
ArrayList Attachments = ctx._source.Attachments;";
    my $QuerySourceFull = '';

    if ( IsArrayRefWithData( $Param{AddAttachment} ) ) {
        @AttachmentsToAdd = $Self->_AttachmentsGet(
            ItemID     => $ItemID,
            FilesID    => $Param{AddAttachment},
            ShowInline => 1,
            UserID     => 1,
        );

        # add attachments
        $QuerySourceFull .= '
ArrayList AttachmentsToAdd = params.AttachmentsToAdd;
for(int i=0;i<AttachmentsToAdd.size();i++){
    ctx._source.Attachments.add(AttachmentsToAdd[i]);
}
ctx._source.AttachmentStorageTemp = AttachmentsToAdd;
ctx._source.AttachmentStorageClearTemp = new HashMap();
' if scalar @AttachmentsToAdd;

    }
    if ( IsArrayRefWithData($AttachmentsToDelete) ) {

        # add attachments
        $QuerySourceFull .= "
for(int i=0;i<AttachmentsToDelete.size();i++){
    for(int j=0;j<Attachments.size();j++){
        if(Attachments[j].FileID == AttachmentsToDelete[i].FileID){
            ctx._source.Attachments.remove(j);
            break;
        }
    }
}
"
    }

    return if !$QuerySourceFull;
    $QuerySourceFull = $QuerySourceBase . $QuerySourceFull;

    my $Query = {
        Method => 'POST',
        Path   => "$Self->{Config}->{IndexRealName}/_update/$ItemID",
        Body   => {
            script => {
                source => $QuerySourceFull,
                params => {
                    AttachmentsToAdd    => \@AttachmentsToAdd   || [],
                    AttachmentsToDelete => $AttachmentsToDelete || [],
                }
            },
        },
        QS => {
            timeout => '30s',
            refresh => 'true',
        }
    };

    my $Response = $Param{EngineObject}->QueryExecute(
        Operation     => 'Generic',
        Query         => $Query,
        ConnectObject => $Param{ConnectObject},
    );

    my $Success = $Param{MappingObject}->ResponseIsSuccess(
        Response => $Response,
    );

    # response did not thrown an error and there was some attachments added
    # in that case run pipeline that will process it's content into readable content
    if ( $Success && scalar @AttachmentsToAdd ) {

        # run attachment pipeline after indexation
        my $Query = {
            Method => 'POST',
            Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
            Body   => {
                query => {
                    terms => {
                        $Self->{Config}->{Identifier} => [$ItemID],
                    },
                },
            },
            QS => {
                pipeline => 'attachment_nested_faq',
                timeout  => '30s',
                refresh  => 'true',
            },
        };

        my $Response = $Param{EngineObject}->QueryExecute(
            Operation     => 'Generic',
            Query         => $Query,
            ConnectObject => $Param{ConnectObject},
        );

        return $Param{MappingObject}->ResponseIsSuccess(
            Response => $Response,
        );
    }

    return;
}

=head2 _AttachmentsGet()

get attachments for faq item

    my @Attachments = $SearchFAQESObject->_AttachmentsGet(
        ItemID => 1,
        FilesID => [1,2,3],
        ShowInline => 1,
    );

=cut

sub _AttachmentsGet {
    my ( $Self, %Param ) = @_;

    my $FAQObject    = $Kernel::OM->Get('Kernel::System::FAQ');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    NEEDED:
    for my $Needed (qw(ItemID UserID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    # search for attachments
    my @Index = $FAQObject->AttachmentIndex(
        ItemID     => $Param{ItemID},
        ShowInline => $Param{ShowInline} || 1,
        UserID     => $Param{UserID},
    );

    my @Attachments;

    my $FilesIDParam = $Param{FilesID} // [];
    my %FilesID      = map { $_ => 1 } @{$FilesIDParam};

    ATTACHMENT:
    for my $Attachment (@Index) {

        # ignore attachment if needed to be filtered by id
        next ATTACHMENT if keys %FilesID && !$FilesID{ $Attachment->{FileID} };

        my %Attachment = $FAQObject->AttachmentGet(
            ItemID => $Param{ItemID},
            FileID => $Attachment->{FileID},
            UserID => 1,
        );

        if ( $Attachment{Content} ) {
            $EncodeObject->EncodeOutput( \$Attachment{Content} );
            $Attachment{Content} = encode_base64( $Attachment{Content}, '' );
        }

        push @Attachments, {
            Inline      => $Attachment->{Inline},
            Filesize    => $Attachment{Filesize},
            FilesizeRaw => $Attachment->{FilesizeRaw},
            ContentType => $Attachment{ContentType},
            Filename    => $Attachment{Filename},
            FileID      => $Attachment->{FileID},
            Content     => $Attachment{Content}
        };
    }

    return @Attachments;
}

1;
