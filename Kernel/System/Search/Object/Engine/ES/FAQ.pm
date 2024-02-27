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

use parent qw( Kernel::System::Search::Object::Default::FAQ );
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
        Identifier           => 'ID',          # column name that represents object id in the field mapping
        ChangeTimeColumnName => 'Changed',     # column representing time of updated data entry
    };

    # load settings for index
    $Self->{Config}->{Settings} = $Self->LoadSettings(
        IndexName => $Self->{Config}->{IndexName},
    );

    # define schema for data
    my $FieldMapping = {
        ID => {
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

    $Self->{AttachmentFieldID} = 'FileID';

    $Self->{AttachmentFields} = {
        $Self->{AttachmentFieldID} => {
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
            ColumnName => 'attachment.content',
            Type       => 'Textarea',
            Alias      => 1,
        },
        Inline => {
            ColumnName => 'inlineattachment',
            Type       => 'Integer',
        },

        #         Created => {
        #             ColumnName => 'created',
        #             Type       => 'Date'
        #         },
        #         CreatedBy => {
        #             ColumnName => 'created_by',
        #             Type       => 'Integer'
        #         },
        #         Changed => {
        #             ColumnName => 'changed',
        #             Type       => 'Date'
        #         },
        #         ChangedBy => {
        #             ColumnName => 'changed_by',
        #             Type       => 'Integer'
        #         },
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
            FAQID => 1,
            FAQNumber => 2022101276000016,
            Title => 'some-title',
            QueueID => 1,
            LockID => 1,
            TypeID => 1,
            ServiceID => 1,
            SLAID => 1,
            OwnerID => 1,
            ResponsibleID => 1,
            PriorityID => 1,
            StateID => 1,
            CustomerID => '333',
            CustomerUserID => 'some-customer-user-id',
            UnlockTimeout => 0,
            EscalationTime => 0,
            EscalationUpdateTime => 0,
            EscalationResponseTime => 0,
            EscalationSolutionTime => 0,
            ArchiveFlag => 1,
            Created => "2022-08-17 13:13:23",
            CreateBy => 1,
            Changed => "2022-08-17 13:13:39",
            ChangeBy => 1,

            # FAQ dynamic fields
            DynamicField_Text => 'TextValue',
            DynamicField_Multiselect => [1,2,3],

            # article fields (denormalized)
            Article_From => 'value',
            Article_To => 'value',
            Article_Cc => 'value',
            Article_Subject => 'value',
            Article_Body => 'value',
            Article_*OtherArticleValues* => 'value',
            Article_SenderTypeID => 'value',
            Article_CommunicationChannelID => 'value',
            Article_IsVisibleForCustomer => 1/0

            # article dynamic fields
            Article_DynamicField_Text => 'TextValue',
            Article_DynamicField_Multiselect => [1,2,3],

            # attachments
            Attachment_ContentAlternative => 'value',
            Attachment_ContentID          => 'value',
            Attachment_Disposition        => 'value',
            Attachment_ContentType        => 'value',
            Attachment_Filename           => 'value',
            Attachment_ID                 => 'value',

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
            Queue        => ['Misc', 'Junk'], # search by queue name
            SLA          => ['SLA5min'],
            SLAID        => [1],
            Lock         => ['Locked'],
            Type         => ['Unclassified', 'Classified'],
            Service      => ['PremiumService'],
            Owner        => ['root@localhost'],
            Responsible  => ['root@localhost'],
            Priority     => ['3 normal'],
            State        => ['open'],
            StateType    => ['new', 'open'],
            Customer     => ['customer123', 'customer12345'], # search by customer name
            CustomerUser => ['customeruser123', 'customeruser12345'], # same as CustomerUserID,
                                                                      # possible to use because of compatibility with
                                                                      # FAQ API
            ChangeByLogin => ['root@localhost'],
            CreateByLogin => ['root@localhost'],

            # fulltext parameter can be used to search by properties specified
            # in sysconfig "SearchEngine::ES::FAQSearchFields###Fulltext"
            Fulltext      => 'elasticsearch',
            #    OR
            Fulltext      => ['elasticsearch', 'kibana'],
            #    OR
            Fulltext      => {
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
            # - article fields (all): [['Article_*']]
            # - article field (specified): [['Article_Body']]
            # - article dynamic fields (all): [['Article_DynamicField_*']]
            # - article dynamic field (specified): [['Article_DynamicField_Body']]
            # - attachment (all standard fields + AttachmentContent): [['Attachment_*']]
            # - attachment (specified): [['Attachment_ContentID']]
    );

    Parameter "AdvancedSearchQuery" is not supported on this object.

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

    # build standard ticket query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        Fields      => \%FAQFields,
        QueryParams => $SegregatedQueryParams->{Ticket},
        Object      => $IndexName,
        _Source     => 1,
    );

    my $FulltextFAQQuery;
    my $FulltextAttachmentQuery;

    # fulltext search
    if ( defined $Fulltext ) {
        my $FulltextValue;
        my $FulltextQueryOperator = 'AND';
        my $StatementOperator     = 'OR';
        if ( ref $Fulltext eq 'HASH' && $Fulltext->{Text} ) {
            $FulltextValue         = $Fulltext->{Text};
            $FulltextQueryOperator = $Fulltext->{QueryOperator}
                if $Fulltext->{QueryOperator};
            $StatementOperator = $Fulltext->{StatementOperator}
                if $Fulltext->{StatementOperator};
        }
        else {
            $FulltextValue = $Fulltext;
        }
        if ( IsArrayRefWithData($FulltextValue) ) {
            $FulltextValue = join " $StatementOperator ", @{$FulltextValue};
        }
        if ( defined $FulltextValue )
        {
            my @FulltextQuery;

            my $FulltextHighlight = $Fulltext->{Highlight};
            my @FulltextHighlightFieldsValid;

            # check validity of highlight fields
            if ( IsArrayRefWithData($FulltextHighlight) ) {
                for my $Property ( @{$FulltextHighlight} ) {
                    my %Field = $Self->ValidFieldsPrepare(
                        Fields => [$Property],
                        Object => $IndexName,
                    );

                    FIELD:
                    for my $Entity ( sort keys %Field ) {
                        next FIELD if !IsHashRefWithData( $Field{$Entity} );
                        push @FulltextHighlightFieldsValid, $Property;
                        last FIELD;
                    }
                }
            }

            # get fields to search
            my $FulltextSearchFields = $Fulltext->{Fields};
            my @FulltextFAQFields;
            my %FulltextFieldsValid;

            if ( IsArrayRefWithData( $FulltextSearchFields->{FAQ} ) ) {
                for my $Property ( @{ $FulltextSearchFields->{FAQ} } ) {
                    my $FulltextField = $Param{MappingObject}->FulltextSearchableFieldBuild(
                        Index  => $IndexName,
                        Entity => $IndexName,
                        Field  => $Property,
                    );

                    if ($FulltextField) {
                        my $Field = $FulltextField;
                        push @FulltextFAQFields, $Field;
                        $FulltextFieldsValid{"${IndexName}_${Property}"} = $Field;
                    }
                }
            }

            my @FulltextAttachmentFields;
            if (
                IsArrayRefWithData( $FulltextSearchFields->{Attachment} )
                && $Self->{Config}->{Settings}->{IndexAttachments}
                )
            {
                for my $Property ( @{ $FulltextSearchFields->{Attachment} } ) {
                    my $FulltextField = $Param{MappingObject}->FulltextSearchableFieldBuild(
                        Index  => $IndexName,
                        Entity => 'Attachment',
                        Field  => $Property,
                    );

                    if ($FulltextField) {
                        my $Field = 'Attachments.' . $FulltextField;
                        push @FulltextAttachmentFields, $Field;
                        $FulltextFieldsValid{"Attachment_${Property}"} = $Field;
                    }
                }
            }

            # build highlight query
            my @HighlightQueryFields;
            HIGHLIGHT:
            for my $HighlightField (@FulltextHighlightFieldsValid) {
                next HIGHLIGHT if !( $FulltextFieldsValid{$HighlightField} );
                push @HighlightQueryFields, {
                    $FulltextFieldsValid{$HighlightField} => {},
                };
            }

            # clean special characters
            $FulltextValue = $Param{EngineObject}->QueryStringReservedCharactersClean(
                String => $FulltextValue,
            );

            if ( scalar @FulltextFAQFields ) {
                $FulltextFAQQuery = {
                    query_string => {
                        fields           => \@FulltextFAQFields,
                        query            => "*$FulltextValue*",
                        default_operator => $FulltextQueryOperator,
                    },
                };
                push @FulltextQuery, $FulltextFAQQuery;
            }

            if ( scalar @FulltextAttachmentFields ) {
                $FulltextAttachmentQuery = {
                    query_string => {
                        fields           => \@FulltextAttachmentFields,
                        query            => "*$FulltextValue*",
                        default_operator => $FulltextQueryOperator,
                    },
                };
                push @FulltextQuery, {
                    nested => {
                        path => [
                            "Attachments"
                        ],
                        query => $FulltextAttachmentQuery,
                    }
                };
            }

            if ( scalar @FulltextQuery ) {
                push @{ $Query->{Body}->{query}->{bool}->{must} }, {
                    bool => {
                        should => \@FulltextQuery,
                    }
                };
                if (@HighlightQueryFields) {
                    $Query->{Body}->{highlight}->{fields} = \@HighlightQueryFields;
                }
            }
        }
    }

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

    my $NestedAttachmentQueryBuilt     = IsHashRefWithData( $AttachmentNestedQuery->{nested}->{query} ) ? 1 : 0;
    my $NestedAttachmentFieldsToSelect = keys %AttachmentFields                                         ? 1 : 0;

    # apply nested article query if there is any valid query param
    # from either article or attachment
    if (
        $NestedAttachmentQueryBuilt
        )
    {
        # apply in article query an attachment query if there is any
        # query param or field regarding attachment
        if ($NestedAttachmentQueryBuilt) {
            push @{ $AttachmentNestedQuery->{nested}->{query}->{bool}->{must} }, $AttachmentNestedQuery;
        }

        push @{ $Query->{Body}->{query}->{bool}->{must} }, $AttachmentNestedQuery;
    }

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
        IndexName  => 'Ticket',
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

notice: fall-back does not support searching by dynamic fields/articles

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
        RunPipeline         => 1,
        NoPermissions       => 1,
    );
}

sub ObjectIndexSet() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function            => '_ObjectIndexSetAction',
        SetEmptyAttachments => 1,
        RunPipeline         => 1,
        NoPermissions       => 1,
    );
}

=head2 ObjectIndexUpdate()

update object to specified index TODO

    my $Success = $SearchObject->ObjectIndexUpdate(
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

        # update FAQs found from query params
        # specify at least one, do not combine "UpdateArticle" with "AddArticle"
        UpdateFAQ  => 1, # base FAQ properties with dynamic fields
        RebuildAttachment => 5, # FAQ nested attachments with dynamic fields
                            # possible:
                            # - any article id: 1
                            # - array of article ids: [1,2,3,4,5]
                            # - every article: '*'

        AddAttachment    => 1, # add nested attachments to FAQ
                            # possible:
                            # - any attachment id: 1
                            # - array of attachment ids: [1,2,3,4,5]

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

    # update base FAQ properties
    # or update specified FAQ articles
    # or add specified FAQ articles
    if ( $Param{ObjectID} ) {
        $Param{UpdateFAQ} = 1;
    }
    if ( $Param{UpdateFAQ} || $Param{RebuildAttachment} || $Param{AddAttachment} ) {
        my $RunPipeline = $Param{AddAttachment} || $Param{RebuildAttachment} ? 1 : 0;

        $Success = $Self->ObjectIndexGeneric(
            %Param,
            Function      => '_ObjectIndexUpdateAction',
            RunPipeline   => $RunPipeline,
            NoPermissions => 1,
        );
    }

    # custom handling of update
    if ( IsHashRefWithData( $Param{CustomFunction} ) ) {
        $Success = $Self->CustomFunction(%Param) if $Success;
    }

    return $Success;
}

=head2 ObjectIndexUpdateGroupID()

update FAQs group id, do not use nested objects as query params

    my $Success = $SearchFAQESObject->ObjectIndexUpdateGroupID(
        Params => {
            NewGroupID => 1,
        }
        ConnectObject => $ConnectObject,
        EngineObject => $EngineObject,
        MappingObject => $MappingObject,
    );

=cut

# TODO
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

    if ( !$Param{Params}->{NewGroupID} ) {
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
                    IgnoreAttachments   => 1,
                    NoPermissions       => $Param{NoPermissions},
                    SetEmptyAttachments => $Param{SetEmptyAttachments},
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
                    my $Offset = $OffsetMultiplier * $ReindexationStep;

                    my $SQLSearchResult = $Self->SQLObjectSearch(
                        %Param,
                        QueryParams => {
                            $Identifier => $SQLDataIDs,
                        },
                        ResultType          => $Param{SQLSearchResultType} || 'ARRAY',
                        IgnoreArticles      => 1,
                        Offset              => $Offset,
                        Limit               => $ReindexationStep,
                        NoPermissions       => $Param{NoPermissions},
                        SetEmptyAttachments => $Param{SetEmptyAttachments},
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
                    Index => 'FAQ',
                );

                # run attachment pipeline after indexation
                my $Query = {
                    Method => 'POST',
                    Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
                    Body   => {
                        query => {
                            terms => {
                                FAQID => $SQLDataIDs,
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

                $Param{EngineObject}->QueryExecute(
                    Operation     => 'Generic',
                    Query         => $Query,
                    ConnectObject => $Param{ConnectObject},
                );
            }
        }
    } while ( $DataCount == $IDLimit );

    return $Success;
}

=head2 ObjectIndexArticle()

update nested article data on FAQ index

    my $Result = $SearchFAQESObject->ObjectIndexArticle(
        ArticleData => $Param{ArticleData},
        Action => 'UpdateArticle', # also possible: 'AddArticle'
    );

=cut

sub ObjectIndexArticle {
    my ( $Self, %Param ) = @_;

    my $SearchChildObject         = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $ArticleObject             = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $EncodeObject              = $Kernel::OM->Get('Kernel::System::Encode');

    my $ArticleData      = $Param{ArticleData};
    my $IndexAttachments = $Self->{Config}->{Settings}->{IndexAttachments};

    my $IndexIsValid = $SearchChildObject->IndexIsValid(
        IndexName => 'FAQ',
    );

    return if !$IndexIsValid;
    return if !$ArticleData->{Success};
    return if !IsArrayRefWithData( $ArticleData->{Data} );

    # check all configured article dynamic fields
    my $ArticleDynamicFields = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Article',
    );

    my %ArticlesToIndex;
    my %AttachmentsToIndex;
    my @AllAttachments;

    my $QuerySource = $IndexAttachments
        ?
        "
ctx._source.AttachmentStorageClearTemp = params.AttachmentStorageClearTemp;
ctx._source.AttachmentStorageTemp = params.AttachmentStorageTemp;
"
        : '';

    my $Success = 1;

    for my $Article ( @{ $ArticleData->{Data} } ) {

        # add article dynamic fields
        DYNAMICFIELDCONFIG:
        for my $DynamicFieldConfig ( @{$ArticleDynamicFields} ) {

            # get the current value for each dynamic field
            my $Value = $DynamicFieldBackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Article->{ArticleID},
            );

            $Article->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
        }

        my @Attachments = ();

        if ($IndexAttachments) {
            my %Index = $ArticleObject->ArticleAttachmentIndex(
                FAQID            => $Article->{FAQID},
                ArticleID        => $Article->{ArticleID},
                ExcludePlainText => 1,
                ExcludeHTMLBody  => 1,
                ExcludeInline    => 1,
            );

            for my $AttachmentID ( sort keys %Index ) {
                my %Attachment = $ArticleObject->ArticleAttachment(
                    FAQID     => $Article->{FAQID},
                    ArticleID => $Article->{ArticleID},
                    FileID    => $AttachmentID,
                );

                push @Attachments, {
                    ContentAlternative => $Attachment{ContentAlternative},
                    ContentID          => $Attachment{ContentID},
                    Disposition        => $Attachment{Disposition},
                    ContentType        => $Attachment{ContentType},
                    Filename           => $Attachment{Filename},
                    ID                 => $AttachmentID,
                    Content            => $Attachment{Content}
                };
            }

            # there is a need to store content as base64
            # as ingest pipeline needs it to create
            # readable attachment content
            ATTACHMENT:
            for my $Result (@Attachments) {
                if ( $Result->{Content} ) {
                    $EncodeObject->EncodeOutput( \$Result->{Content} );
                    $Result->{Content} = encode_base64( $Result->{Content}, '' );
                }
                $Result->{ArticleID} = $Article->{ArticleID};
            }
        }

        $Article->{Attachments} = \@Attachments;

        my $ArticleTemp = $Article;

        undef $Article;
        push @{ $ArticlesToIndex{ $ArticleTemp->{FAQID} } },    $ArticleTemp;
        push @{ $AttachmentsToIndex{ $ArticleTemp->{FAQID} } }, @{ $ArticleTemp->{Attachments} };

    }

    for my $FAQID ( sort keys %ArticlesToIndex ) {

        my $Query = {
            Method => 'POST',
            Path   => "$Self->{Config}->{IndexRealName}/_update/$FAQID",
            Body   => {
                script => {
                    source => $QuerySource,
                    params => {
                        Articles              => $ArticlesToIndex{$FAQID}    || [],
                        AttachmentStorageTemp => $AttachmentsToIndex{$FAQID} || [],
                        AttachmentStorageClearTemp => {},
                    }
                },
            },
        };

        my $Response = $Param{EngineObject}->QueryExecute(
            Operation     => 'Generic',
            Query         => $Query,
            ConnectObject => $Param{ConnectObject},
        );

        $Success = $Param{MappingObject}->ResponseIsSuccess(
            Response => $Response,
        ) if $Success;
    }

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

    my $SearchFAQAttachmentObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::FAQAttachment');
    my %FAQAttachmentFields       = %{ $SearchFAQAttachmentObject->{Fields} };

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
        Result => $Response,
        Config => $Param{Config},
    );
}

=head2 SQLObjectSearch()

TODO: add support for child "Field" parameters.

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

            #             if ( !$Param{IgnoreAttachmentsTemp} ) {
            $FAQ->{AttachmentStorageTemp} = [];

            #             }

            if ( !$Param{IgnoreDynamicFields} ) {
                DYNAMICFIELDCONFIG:
                for my $DynamicFieldConfig ( @{$FAQDynamicFieldList} ) {

                    # get the current value for each dynamic field
                    my $Value = $DynamicFieldBackendObject->ValueGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        ObjectID           => $FAQ->{FAQID},
                    );

                    $FAQ->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
                }
            }

            my @Attachments;

            if ( !$Param{IgnoreAttachments} ) {

                # search for attachments
                my @Index = $FAQObject->AttachmentIndex(
                    ItemID     => $FAQ->{ID},
                    ShowInline => 1,
                    UserID     => 1,
                );

                for my $Attachment (@Index) {
                    my %Attachment = $FAQObject->AttachmentGet(
                        ItemID => $FAQ->{ID},
                        FileID => $Attachment->{FileID},
                        UserID => 1,
                    );

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

                # there is need to store content as base64
                ATTACHMENT:
                for my $Result (@Attachments) {
                    if ( $Result->{Content} ) {
                        $EncodeObject->EncodeOutput( \$Result->{Content} );
                        $Result->{Content} = encode_base64( $Result->{Content}, '' );
                    }
                }

                $FAQ->{Attachments} = \@Attachments;

                #                 if ( !$Param{IgnoreAttachmentsTemp} ) {
                push @{ $FAQ->{AttachmentStorageTemp} }, @Attachments;

                #                 }

                #                 if ( !$Param{IgnoreAttachmentsTemp} ) {
                $FAQ->{AttachmentStorageClearTemp} = {};

                #                 }
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

        my $AllCategoryGroupHashRef;
        if ( scalar @GroupQueryParam ) {
            $AllCategoryGroupHashRef = $FAQObject->CategoryGroupGetAll(
                UserID => 1,
            );
        }

        my $NoPermissionCheck = !scalar @GroupQueryParam;

        ROW:
        for my $Row ( @{ $SQLSearchResult->{Data} } ) {

            my $PermissionOk        = $NoPermissionCheck;
            my $CategoryPermissions = $AllCategoryGroupHashRef->{ $Row->{CategoryID} };

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
                    @{ $Row->{GroupID} } = keys %{$CategoryPermissions};
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

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    my %AllArticleFields    = ( %{ $SearchArticleObject->{Fields} }, %{ $SearchArticleObject->{ExternalFields} } );

    my $AllAttachmentFields = $Self->{AttachmentFields};

    PARAMFIELD:
    for my $ParamField ( @{ $Param{Fields} } ) {

        # get information about field types if field
        # matches specified regexp
        if ( $ParamField =~ m{\A(FAQ|Article)_DynamicField_(.+)} ) {
            my $ObjectType       = $1;
            my $DynamicFieldName = $2;

            if ( $DynamicFieldName eq '*' ) {
                my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
                    ObjectType => $ObjectType,
                );

                for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next PARAMFIELD if !$Info->{ColumnName};
                    $ValidFields{ $ObjectType . '_DynamicField' }->{ $Info->{ColumnName} } = $Info;
                }
            }
            else {
                # get single dynamic field config
                my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                    Name => $DynamicFieldName,
                );

                next PARAMFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next PARAMFIELD if $ObjectType ne $DynamicFieldConfig->{ObjectType};

                if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        ObjectType         => $ObjectType,
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next PARAMFIELD if !$Info->{ColumnName};
                    $ValidFields{ $ObjectType . '_DynamicField' }->{ $Info->{ColumnName} } = $Info;
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

        # apply "Article" fields
        elsif ( $ParamField =~ m{\AArticle_(.+)\z} ) {
            my $ArticleField = $1;

            # get single "Article" field
            if ( $AllArticleFields{$ArticleField} ) {
                $ValidFields{Article}->{$ArticleField} = $AllArticleFields{$ArticleField};
            }

            # get all "Article" fields
            elsif ( $ArticleField && $ArticleField eq '*' ) {
                for my $ArticleField ( sort keys %AllArticleFields ) {
                    $ValidFields{Article}->{$ArticleField} = $AllArticleFields{$ArticleField};
                }
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

                my $AddArticleQueuedBefore    = $QueuedOperation->{Data}->{AddArticle}    || '';
                my $UpdateArticleQueuedBefore = $QueuedOperation->{Data}->{UpdateArticle} || '';
                my $UpdateArticleQueuedNow    = $Param{QueueToAdd}->{Data}->{UpdateArticle};

                # check if articles to update has been queued now
                if ( IsArrayRefWithData($UpdateArticleQueuedNow) && $UpdateArticleQueuedBefore ne '*' ) {
                    my $ArticlesToQueue     = $UpdateArticleQueuedNow;
                    my %QueuedArticleIDsNow = map { $_ => 1 } @{$ArticlesToQueue};

                    # if there was any article add queued before
                    # then check if any of the same ids was also
                    # queued to update and prevent it as add operation
                    # have higher priority
                    if ( IsArrayRefWithData($AddArticleQueuedBefore) ) {
                        my %QueuedArticleAddIDsBefore = map { $_ => 1 } @{$AddArticleQueuedBefore};
                        for my $QueuedArticleAddBefore ( sort keys %QueuedArticleAddIDsBefore ) {
                            delete $QueuedArticleIDsNow{$QueuedArticleAddBefore};
                        }
                        @{$ArticlesToQueue} = keys %QueuedArticleIDsNow;
                    }
                    if ( IsArrayRefWithData($UpdateArticleQueuedBefore) ) {
                        my %QueuedArticleIDsBefore = map { $_ => 1 } @{$UpdateArticleQueuedBefore};
                        my %MergedArticleIDs       = ( %QueuedArticleIDsBefore, %QueuedArticleIDsNow );
                        my @MergedArticleIDsArray  = keys %MergedArticleIDs;

                        $ArticlesToQueue = \@MergedArticleIDsArray;
                    }
                    if ( IsArrayRefWithData($ArticlesToQueue) ) {
                        $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{UpdateArticle}
                            = $ArticlesToQueue;
                        $Changed = 1;
                    }
                }
                elsif ( $UpdateArticleQueuedNow && $UpdateArticleQueuedNow eq '*' ) {
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{UpdateArticle} = '*';
                    $Changed = 1;
                }

                my $AddArticleQueuedNow = $Param{QueueToAdd}->{Data}->{AddArticle};

                # check if articles to add has been queued now
                if ( IsArrayRefWithData($AddArticleQueuedNow) ) {
                    my $ArticlesToQueue     = $AddArticleQueuedNow;
                    my %QueuedArticleIDsNow = map { $_ => 1 } @{$ArticlesToQueue};

                    # if there was any article update queued before
                    # then check if any of the same ids was also
                    # queued to add and override it as add operation
                    # have higher priority
                    if ( IsArrayRefWithData($UpdateArticleQueuedBefore) ) {
                        my %QueuedArticleUpdateIDsBefore = map { $_ => 1 } @{$UpdateArticleQueuedBefore};
                        for my $QueuedArticleAddNow ( sort keys %QueuedArticleIDsNow ) {
                            delete $QueuedArticleUpdateIDsBefore{$QueuedArticleAddNow};
                        }
                        my @ArticlesToUpdate = keys %QueuedArticleUpdateIDsBefore;

                        if ( scalar @ArticlesToUpdate ) {
                            $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{UpdateArticle}
                                = \@ArticlesToUpdate;
                        }
                        else {
                            delete $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{UpdateArticle};
                        }

                        $Changed = 1;
                    }

                    if ( IsArrayRefWithData($AddArticleQueuedBefore) ) {
                        my %QueuedArticleIDsBefore = map { $_ => 1 } @{$AddArticleQueuedBefore};
                        my %MergedArticleIDs       = ( %QueuedArticleIDsBefore, %QueuedArticleIDsNow );
                        my @MergedArticleIDsArray  = keys %MergedArticleIDs;

                        $ArticlesToQueue = \@MergedArticleIDsArray;
                    }
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1]->{Data}->{AddArticle} = $ArticlesToQueue;
                    $Changed = 1;
                }

                if ($Changed) {
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

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');

    # some FAQs ids with a data to index should be found
    return if !$Param{FAQIDs};

    # index FAQ base values with dfs
    my $Success = $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexAdd',
    );

    return if !$Success;

    # index FAQ articles
    # use article module, but specify index into
    # "FAQ", so that "ObjectIndexArticle" function will be executed
    $SearchArticleObject->ObjectIndexAdd(
        IndexInto   => 'FAQ',
        QueryParams => {
            FAQID => $Param{FAQIDs},
        },
        Index         => 'Article',
        MappingObject => $Param{MappingObject},
        ConnectObject => $Param{ConnectObject},
        EngineObject  => $Param{EngineObject},
        Config        => $Param{Config},
    );

    return $Success;
}

sub _ObjectIndexUpdateAction {
    my ( $Self, %Param ) = @_;

    my $Success             = 1;
    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    if ( $Param{UpdateFAQ} ) {

        # index FAQ base values with dfs
        $Success = $Self->SUPER::_ObjectIndexAction(
            %Param,
            Function => 'ObjectIndexUpdate',
        );
    }
    if ( $Param{UpdateAttachment} ) {

        # add FAQ articles
        $Success = $SearchArticleObject->ObjectIndexUpdateFAQArticles(
            IndexInto   => 'FAQ',
            QueryParams => {
                ArticleID => $Param{AddArticle},
            },
            Index         => 'Article',
            Action        => 'AddArticle',
            MappingObject => $Param{MappingObject},
            EngineObject  => $Param{EngineObject},
            ConnectObject => $Param{ConnectObject},
            Config        => $Param{Config},
        ) if $Success;
    }
    ARTICLE: {
        if ( $Param{UpdateArticle} ) {
            my $QueryParams = {
                ArticleID => $Param{UpdateArticle}
            };

            # update all articles
            if ( $Param{UpdateArticle} eq '*' ) {
                my @FAQIDs;

                if (
                    IsHashRefWithData( $Param{DataToIndex} )
                    &&
                    IsArrayRefWithData( $Param{DataToIndex}->{Data} )
                    )
                {
                    FAQ:
                    for my $FAQ ( @{ $Param{DataToIndex}->{Data} } ) {
                        next FAQ if !IsHashRefWithData($FAQ) || !$FAQ->{FAQID};
                        push @FAQIDs, $FAQ->{FAQID};
                    }
                }
                last ARTICLE if !scalar @FAQIDs;
                $QueryParams = {
                    FAQID => \@FAQIDs,
                };
            }

            # update FAQ articles
            $Success = $SearchArticleObject->ObjectIndexUpdateFAQArticles(
                IndexInto     => 'FAQ',
                QueryParams   => $QueryParams,
                Index         => 'Article',
                Action        => 'UpdateArticle',
                MappingObject => $Param{MappingObject},
                EngineObject  => $Param{EngineObject},
                ConnectObject => $Param{ConnectObject},
                Config        => $Param{Config},
            ) if $Success;
        }
    }

    return $Success;
}

sub _ObjectIndexSetAction {
    my ( $Self, %Param ) = @_;

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');

    return if !$Param{FAQIDs};

    # index FAQ base values with dfs
    my $Success = $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexSet',
    );

    return if !$Success;

    # index FAQ articles
    $SearchArticleObject->ObjectIndexAdd(
        IndexInto   => 'FAQ',
        QueryParams => {
            FAQID => $Param{FAQIDs},
        },
        Index         => 'Article',
        MappingObject => $Param{MappingObject},
        ConnectObject => $Param{ConnectObject},
        EngineObject  => $Param{EngineObject},
        Config        => $Param{Config},
    );

    return $Success;
}

1;
