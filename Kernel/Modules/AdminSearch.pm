# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);
use Kernel::System::Search;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    # prevent using constructor that checks search engine
    # as it's not needed here
    $Self->{Engines} = Kernel::System::Search->EngineListGet();

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $CacheObject         = $Kernel::OM->Get('Kernel::System::Cache');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ReindexationObject  = $Kernel::OM->Get('Kernel::System::Search::Admin::Reindexation');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $SearchObject        = $Kernel::OM->Get('Kernel::System::Search');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $YAMLObject          = $Kernel::OM->Get('Kernel::System::YAML');

    my $ClusterID = $ParamObject->GetParam( Param => 'ClusterID' ) || '';

    if ( $Self->{Subaction} eq 'Change' ) {
        if ( !$ClusterID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ClusterID !'),
            );
        }

        my $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $ClusterID,
        );

        if ( !IsHashRefWithData($ClusterData) ) {
            return $LayoutObject->ErrorScreen(
                Message =>
                    $LayoutObject->{LanguageObject}->Translate( 'Could not get data for ClusterID %s', $ClusterID ),
            );
        }

        # show overview of an existing cluster
        return $Self->_ShowEdit(
            %Param,
            ClusterID   => $ClusterID,
            ClusterData => $ClusterData,
            Action      => 'Change',
        );
    }
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my $GetParam = $Self->_GetBaseClusterParams();

        if ( !$ClusterID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ClusterID !'),
            );
        }

        my %ClusterData;
        for my $Property (qw(Name ValidID Description EngineID)) {
            $ClusterData{$Property} = $GetParam->{$Property};
        }

        $ClusterData{UserID} = $Self->{UserID};

        my %Error;
        if ( !$ClusterData{Name} ) {
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('This field is required.');
        }
        else {
            my $NameExists = $SearchClusterObject->NameExistsCheck(
                ID   => $ClusterID,
                Name => $ClusterData{Name},
            );

            if ($NameExists) {
                $Error{NameServerError}        = 'ServerError';
                $Error{NameServerErrorMessage} = Translatable('There is another cluster with the same name.');
            }
        }

        if (%Error) {
            return $Self->_ShowEdit(
                %Error,
                %Param,
                ClusterID   => $ClusterID,
                ClusterData => \%ClusterData,
                Action      => 'Change',
                Error       => 1,
            );
        }

        my $Success = $SearchClusterObject->ClusterUpdate(
            ClusterID => $ClusterID,
            %{$GetParam},
        );

        if ( !$Success ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('There was an error updating the web service.'),
            );
        }

        if (
            defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
            && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
            )
        {

            # if the user would like to continue editing the cluster, just redirect to the edit screen
            return $LayoutObject->Redirect(
                OP =>
                    "Action=AdminSearch;Subaction=Change;ClusterID=$ClusterID"
            );
        }

        # otherwise return to overview
        return $LayoutObject->Redirect( OP => "Action=$Self->{Action}" );
    }
    elsif ( $Self->{Subaction} eq 'IndexRemoveAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my $Success       = 0;
        my $IndexRealName = $ParamObject->GetParam( Param => 'IndexRealName' ) || '';

        if ($IndexRealName) {
            $Success = $SearchObject->IndexRemove(
                IndexRealName => $IndexRealName,
            );
        }

        my $ResultJSON = $LayoutObject->JSONEncode(
            Data => {
                Success => $Success,
            }
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $ResultJSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'Add' ) {
        return $Self->_ShowEdit(
            Action => 'Add',
        );
    }
    elsif ( $Self->{Subaction} eq 'AddAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my $ClusterData;

        my $GetParam = $Self->_GetBaseClusterParams();

        $ClusterData->{Name}        = $GetParam->{Name};
        $ClusterData->{Description} = $GetParam->{Description};
        $ClusterData->{EngineID}    = $GetParam->{EngineID};
        $ClusterData->{ValidID}     = $GetParam->{ValidID};

        my %Error;
        if ( !$GetParam->{Name} ) {
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('This field is required.');
        }
        else {

            # check if name is duplicated
            my $NameExists = $SearchClusterObject->NameExistsCheck(
                ID   => $ClusterID,
                Name => $GetParam->{Name},
            );

            if ($NameExists) {
                $Error{NameServerError}        = 'ServerError';
                $Error{NameServerErrorMessage} = Translatable('There is another cluster with the same name.');
            }
        }

        if ( !$GetParam->{EngineID} ) {
            $Error{EngineIDError}        = 'ServerError';
            $Error{EngineIDErrorMessage} = Translatable('This field is required.');
        }

        if (%Error) {
            return $Self->_ShowEdit(
                %Error,
                %Param,
                ClusterID   => $ClusterID,
                ClusterData => $ClusterData,
                Action      => 'Add',
                Error       => 1,
            );
        }

        my $ClusterID = $SearchClusterObject->ClusterAdd(
            Name        => $ClusterData->{Name},
            ValidID     => $ClusterData->{ValidID},
            Description => $ClusterData->{Description},
            EngineID    => $ClusterData->{EngineID},
            UserID      => $Self->{UserID},
        );

        if ( !$ClusterID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('There was an error creating the cluster.'),
            );
        }

        my $Notify = $LayoutObject->{LanguageObject}->Translate(
            'Cluster "%s" created!',
            $ClusterData->{Name},
        );

        $Self->_ClusterSynchronize(
            ClusterID => $ClusterID
        );

        # return overview
        return $Self->_ShowOverview(
            %Param,
            Notify => $Notify,
            Action => 'Overview'
        );
    }
    elsif ( $Self->{Subaction} eq 'DeleteAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $ClusterID,
        );

        my $Success = $SearchClusterObject->ClusterDelete(
            ClusterID => $ClusterID,
            UserID    => $Self->{UserID},
        );

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success        => $Success,
                DeletedCluster => $ClusterData->{Name},
            },
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'SynchronizeAction' ) {
        return $Self->_ClusterSynchronize(
            ClusterID => $ClusterID,
        );
    }
    elsif ( $Self->{Subaction} eq 'Reindexation' ) {
        return $Self->_ShowReindexation(
            ClusterID => $ClusterID,
        );

    }
    elsif ( $Self->{Subaction} eq 'ReindexationAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my @IndexArray = $ParamObject->GetArray( Param => 'IndexArray[]' );

        my @Params;
        for my $Index (@IndexArray) {
            push @Params, '--index';
            push @Params, $Index;
        }

        my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::Search::Reindex');
        my ( $Result, $ExitCode );
        {
            local *STDOUT;
            open STDOUT, '>:utf8', \$Result;    ## no critic
            $ExitCode = $CommandObject->Execute(@Params);
        }

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success => $ExitCode,
            }
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'StopReindexationAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my $Status = $ReindexationObject->StopReindexation();

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success => $Status ? 1 : 0,
            }
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'ReindexingProcessPercentage' ) {
        my $ReindexationQuery = $ReindexationObject->IndexReindexationStatus();

        my $Percentage = $CacheObject->Get(
            Type => 'ReindexingProcess',
            Key  => 'Percentage',
        );

        my %ResponseData;
        if ( !defined $Percentage ) {
            %ResponseData = (
                Finished => 1,
            );
        }
        else {
            %ResponseData = (
                Percentage        => $Percentage,
                ReindexationQueue => $ReindexationQuery,
            );
        }

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                %ResponseData,
            },
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'CheckEqualityAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my @IndexArray = $ParamObject->GetArray( Param => 'IndexArray[]' );

        my $Result = $ReindexationObject->DataEqualitySet(
            Indexes   => \@IndexArray,
            ClusterID => $ClusterID,
        );

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success => $Result ? 1 : 0,
            },
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'NodeAdd' ) {
        return $Self->_ShowNodeSection(
            ClusterID => $ClusterID,
            Action    => 'NodeAdd',
        );
    }
    elsif ( $Self->{Subaction} eq 'NodeAddAction' ) {
        my $Result = $Self->_NodeBaseOperationAction(
            %Param,
            ClusterID => $ClusterID,
        );

        my $Error    = $Result->{Error};
        my $GetParam = $Result->{GetParam};

        if ( IsHashRefWithData($Error) ) {
            return $Self->_ShowNodeSection(
                %{$Error},
                %Param,
                %{$GetParam},
                ClusterID => $ClusterID,
                Action    => 'NodeAdd',
            );
        }

        my $NodeID = $SearchClusterObject->ClusterCommunicationNodeAdd(
            ClusterID => $ClusterID,
            UserID    => $Self->{UserID},
            Password  => $GetParam->{Password},
            Login     => $GetParam->{Login},
            %{$GetParam},
        );

        if ( !$NodeID ) {
            $Error->{OperationError}        = 'ServerError';
            $Error->{OperationErrorMessage} = Translatable("Can't add node. Check logs or contact with support.");
            return $Self->_ShowNodeSection(
                %{$Error},
                %{$GetParam},
                ClusterID => $ClusterID,
                Action    => 'NodeAdd',
            );
        }

        return $Self->_ShowEdit(
            ClusterID => $ClusterID,
            Action    => 'Change',
        );
    }
    elsif ( $Self->{Subaction} eq 'NodeChange' ) {
        my $NodeID = $ParamObject->GetParam( Param => 'NodeID' ) || '';

        if ( !$ClusterID && !$NodeID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ClusterID !'),
            );
        }
        return $Self->_ShowNodeSection(
            %Param,
            ClusterID => $ClusterID,
            NodeID    => $NodeID,
            Action    => 'NodeChange'
        );
    }
    elsif ( $Self->{Subaction} eq 'NodeChangeAction' ) {
        my $NodeID = $ParamObject->GetParam( Param => 'NodeID' ) || '';

        my $Result = $Self->_NodeBaseOperationAction(
            %Param,
            NodeID    => $NodeID,
            ClusterID => $ClusterID,
        );

        my $Error    = $Result->{Error};
        my $GetParam = $Result->{GetParam};

        if ( IsHashRefWithData($Error) ) {
            return $Self->_ShowNodeSection(
                %{$Error},
                %Param,
                %{$GetParam},
                ClusterID => $ClusterID,
                Action    => 'NodeChange',
            );
        }

        my $Success = $SearchClusterObject->ClusterCommunicationNodeUpdate(
            %{$GetParam},
            ClusterID     => $ClusterID,
            UserID        => $Self->{UserID},
            PasswordClear => $GetParam->{AuthRequired} ? 0 : 1,
        );

        if ( !$Success ) {
            $Error->{AddingError}        = 'ServerError';
            $Error->{AddingErrorMessage} = Translatable("Can't update node. Check logs or contact with support.");
            return $Self->_ShowNodeSection(
                %{$Error},
                %{$GetParam},
                ClusterID => $ClusterID,
                Action    => 'NodeChange',
            );
        }

        if (
            defined $ParamObject->GetParam( Param => 'ContinueAfterSave' )
            && ( $ParamObject->GetParam( Param => 'ContinueAfterSave' ) eq '1' )
            )
        {
            return $Self->_ShowNodeSection(
                NodeID => $NodeID,
                %{$GetParam},
                ClusterID => $ClusterID,
                Action    => 'NodeChange'
            );
        }

        return $Self->_ShowEdit(
            ClusterID => $ClusterID,
            Action    => 'Change',
        );
    }
    elsif ( $Self->{Subaction} eq 'NodeCopyAction' ) {
        my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $NodeID      = $ParamObject->GetParam( Param => 'NodeID' );

        if ( !$NodeID ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need NodeID!",
            );
            return;
        }

        my $NodeData = $SearchClusterObject->ClusterCommunicationNodeGet(
            NodeID => $NodeID,
        );

        my $Count    = 1;
        my $NodeName = $LayoutObject->{LanguageObject}->Translate( '%s (copy) %s', $NodeData->{Name}, $Count );

        # TODO: ???
        while (
            IsHashRefWithData(
                $SearchClusterObject->ClusterCommunicationNodeGet(
                    Name      => $NodeName,
                    ClusterID => $NodeData->{ClusterID}
                )
            )
            && $Count < 100
            )
        {
            $NodeName =~ s/\d+$/$Count/;
            $Count++;
        }

        my $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $NodeData->{ClusterID}
        );

        $NodeData->{Name} = $NodeName;

        my $Result = $SearchClusterObject->ClusterCommunicationNodeAdd(
            %{$NodeData},
            UserID => $Self->{UserID}
        );
        if ( !$Result ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Error: Can't add copy of node!",
            );

            return $Self->_ShowEdit(
                %Param,
                ClusterID => $NodeData->{ClusterID},
                Action    => 'Change',
                Notify    => "Error while copying node!"
            );
        }

        return $Self->_ShowEdit(
            %Param,
            ClusterID => $NodeData->{ClusterID},
            Action    => 'Change',
        );
    }
    elsif ( $Self->{Subaction} eq 'NodeDeleteAction' ) {
        $LayoutObject->ChallengeTokenCheck();

        my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $NodeID      = $ParamObject->GetParam( Param => 'NodeID' );

        if ( !$NodeID ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need NodeID!",
            );
            return;
        }

        my $Success = $SearchClusterObject->ClusterCommunicationNodeRemove(
            NodeID => $NodeID,
            UserID => $Self->{UserID},
        );

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success => $Success,
            },
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'TestNodeConnection' ) {
        my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
        my $EngineObject = $Kernel::OM->Get("Kernel::System::Search::Engine::$SearchObject->{Config}->{ActiveEngine}");

        my %GetParam;

        for my $ParamName (
            qw(AuthRequired NodeID NodeFullPath Protocol Host Port Path Login Password )
            )
        {
            $GetParam{$ParamName} = $ParamObject->GetParam( Param => $ParamName ) || '';
        }

        # when auth is enabled
        # set password
        # empty password means stored in db password if node exists
        my $Password;
        my $AuthRequired = $GetParam{AuthRequired};
        if ( $AuthRequired && !$GetParam{Password} && $GetParam{NodeID} ) {
            my $ClusterCommunicationNode = $SearchClusterObject->ClusterCommunicationNodeGet(
                NodeID => $GetParam{NodeID},
            );

            $Password = $ClusterCommunicationNode->{Password} // '';
        }
        else {
            $Password = $GetParam{Password};
        }

        my $Connection = $EngineObject->CheckNodeConnection(
            %GetParam,
            Password => $Password,
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $Connection ? '{"Connected":1}' : '{"Connected":0}',
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'ClusterNodeExport' ) {
        my $NodeID    = $ParamObject->GetParam( Param => 'NodeID' );
        my $ClusterID = $ParamObject->GetParam( Param => 'ClusterID' );
        my $Filename;
        my $DataToExport;

        if ( !$ClusterID && !$NodeID ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need NodeID or ClusterID!",
            );
            return;
        }
        elsif ($ClusterID) {
            $DataToExport = $SearchClusterObject->ClusterCommunicationNodeList(
                ClusterID => $ClusterID
            );

            my $ClusterData = $SearchClusterObject->ClusterGet(
                ClusterID => $ClusterID
            );

            $Filename = "Export_Cluster_$ClusterData->{Name}_Nodes.yml";

            if ( !IsArrayRefWithData($DataToExport) ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "No nodes for this cluster.",
                );
                return;
            }

            for my $Node ( @{$DataToExport} ) {
                delete $Node->{ClusterID};
                delete $Node->{NodeID};
                delete $Node->{Password};
            }
        }
        else {
            my $CommunicationNodeData = $SearchClusterObject->ClusterCommunicationNodeGet(
                NodeID => $NodeID,
            );

            my $ClusterData = $SearchClusterObject->ClusterGet(
                ClusterID => $CommunicationNodeData->{ClusterID},
            );

            if ( !IsHashRefWithData($CommunicationNodeData) ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "No node with given ID.",
                );
                return;
            }

            if ( !IsHashRefWithData($ClusterData) ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "No cluster with given ID.",
                );
                return;
            }

            my $ClusterName = $ClusterData->{Name};

            $Filename = "Export_Cluster_$ClusterData->{Name}_Node_$CommunicationNodeData->{Name}.yml";

            delete $CommunicationNodeData->{ClusterID};
            delete $CommunicationNodeData->{NodeID};
            delete $CommunicationNodeData->{Password};

            $DataToExport = [
                $CommunicationNodeData,
            ];
        }

        my $NodesDataYAML = $YAMLObject->Dump( Data => $DataToExport );

        return $LayoutObject->Attachment(
            ContentType => 'text/html; charset=' . $LayoutObject->{Charset},
            Content     => $NodesDataYAML,
            Type        => 'attachment',
            Filename    => $Filename,
            NoCache     => 1,
        );

    }
    if ( $Self->{Subaction} eq 'ClusterNodeImport' ) {
        $LayoutObject->ChallengeTokenCheck();

        my %UploadStuff = $ParamObject->GetUploadAll(
            Param  => 'FileUpload',
            Source => 'string',
        );

        my $OverwriteExistingNodes = $ParamObject->GetParam( Param => 'OverwriteExistingNodes' ) || '';
        my $ClusterID              = $ParamObject->GetParam( Param => 'ClusterID' );

        my $NodesImport = $SearchClusterObject->ClusterCommunicationNodesImport(
            Content                => $UploadStuff{Content},
            OverwriteExistingNodes => $OverwriteExistingNodes,
            UserID                 => $Self->{UserID},
            ClusterID              => $ClusterID,
        );

        if ( !$NodesImport->{Success} ) {
            return $Self->_ShowEdit(
                %Param,
                ClusterID => $ClusterID,
                Action    => 'Change',
                Notify    => $NodesImport->{Message},
            );
        }

        if ( $NodesImport->{AddedNodes} ) {
            my $Info = $LayoutObject->{LanguageObject}->Translate(
                'The following nodes have been added successfully: %s.',
                $NodesImport->{AddedNodes}
            );
            push @{ $Param{Notify} }, {
                Info => $Info
            };
        }
        if ( $NodesImport->{UpdatedNodes} ) {
            my $Info = $LayoutObject->{LanguageObject}->Translate(
                'The following nodes have been updated successfully: %s.',
                $NodesImport->{UpdatedNodes}
            );
            push @{ $Param{Notify} }, {
                Info => $Info,
            };
        }
        if ( $NodesImport->{NodesErrors} ) {
            my $Info = $LayoutObject->{LanguageObject}->Translate(
                'There where errors adding/updating the following nodes: %s. Please check the log file for more information.',
                $NodesImport->{NodesErrors}
            );
            push @{ $Param{Notify} }, {
                Priority => 'Error',
                Info     => $Info,
            };
        }

        return $Self->_ShowEdit(
            %Param,
            ClusterID => $ClusterID,
            Action    => 'Change',
        );

    }

    my $Notify;

    my $DeletedCluster = $ParamObject->GetParam( Param => 'DeletedCluster' ) || '';
    if ($DeletedCluster) {
        $Notify = $LayoutObject->{LanguageObject}->Translate(
            'Cluster "%s" deleted!',
            $DeletedCluster,
        );
    }

    return $Self->_ShowOverview(
        %Param,
        Notify => $Notify,
        Action => 'Overview',
    );
}

sub _ShowOverview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $MainObject          = $Kernel::OM->Get('Kernel::System::Main');

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::Search' => {
            Silent => 1,
        },
    );

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    if ( $Param{Notify} ) {
        $Output .= $LayoutObject->Notify(
            Info => $Param{Notify},
        );
    }

    if ( !$SearchObject->{Config}->{Enabled} ) {
        $Output .= $LayoutObject->Notify(
            Info     => 'Please activate search engine first!',
            Priority => 'Error',
            Link     => $LayoutObject->{Baselink}
                . 'Action=AdminSystemConfiguration;Subaction=View;Setting=SearchEngine%23%23%23Enabled;'
        );
    }

    # call all needed template blocks
    $LayoutObject->Block(
        Name => 'Main',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionAdd' );
    $LayoutObject->Block( Name => 'OverviewHeader' );
    $LayoutObject->Block( Name => 'OverviewResult' );

    my $ClusterList = $SearchClusterObject->ClusterList(
        Valid => 0,
    );

    if ( !IsHashRefWithData($ClusterList) ) {
        $LayoutObject->Block( Name => 'NoDataFoundMsg' );
    }
    else {
        my @ClusterIDs = sort { $ClusterList->{$a} cmp $ClusterList->{$b} }
            keys %{$ClusterList};

        CLUSTERID:
        for my $ClusterID (@ClusterIDs) {
            next CLUSTERID if !$ClusterID;

            my $Cluster = $SearchClusterObject->ClusterGet( ClusterID => $ClusterID );
            next CLUSTERID if !IsHashRefWithData($Cluster);

            my $ValidStrg = $ValidObject->ValidLookup(
                ValidID => $Cluster->{ValidID},
            );

            # Engine isn't in the configuration
            if ( !$Self->{Engines}->{ $Cluster->{EngineID} } ) {
                $Self->{Engines}->{ $Cluster->{EngineID} } = 'Unregistered';
            }

            my $Data = {
                ID          => $ClusterID,
                Name        => $Cluster->{Name},
                Description => $Cluster->{Description} || '-',
                Engine      => $Self->{Engines}->{ $Cluster->{EngineID} },
                Valid       => $ValidStrg,
            };

            $LayoutObject->Block(
                Name => 'OverviewResultRow',
                Data => $Data,
            );
        }
    }

    my $ConnectObject;

    my $ActiveClusterConfig = $SearchClusterObject->ActiveClusterGet();

    if ( $SearchObject->{EngineObject} ) {
        $ConnectObject = $SearchObject->{EngineObject}->Connect(
            Config => $SearchObject->{Config},
            Silent => 1,
        );
    }
    elsif ( $SearchObject->{Config}->{ActiveEngine} ) {
        my $Loaded = $MainObject->Require(
            "Kernel::System::Search::Engine::$SearchObject->{Config}->{ActiveEngine}",
            Silent => $Param{Silent},
        );
        if ($Loaded) {
            my $EngineObject = $Kernel::OM->Get(
                "Kernel::System::Search::Engine::$SearchObject->{Config}->{ActiveEngine}"
            );
            $ConnectObject = $EngineObject->Connect(
                Config => $SearchObject->{Config},
                Silent => 1,
            );
        }
        else {
            $ConnectObject->{Error} = 1;
        }
    }

    if ( !$SearchObject->{Config}->{ActiveEngine} || $SearchObject->{Config}->{ActiveEngine} eq 'Unregistered' ) {
        $LayoutObject->Block(
            Name => 'Status',
            Data => {
                ClusterName       => $ActiveClusterConfig->{Name},
                ConnectionMessage => 'Engine of the active cluster is not registered!',
                ConnectionStatus  => 'Failed',
            },
        );
    }
    else {
        my $ConnectionStrg   = $ConnectObject->{Error} ? 'failed' : 'available';
        my $ConnectionStatus = $ConnectObject->{Error} ? 'Failed' : 'Available';

        $LayoutObject->Block(
            Name => 'Status',
            Data => {
                ClusterName           => $ActiveClusterConfig->{Name},
                ConnectionMessage     => $ConnectionStrg,
                ConnectionStatus      => $ConnectionStatus,
                SearchEngineIsRunning => IsHashRefWithData( $SearchObject->{Error} ) ? 0 : 1,
            },
        );
    }

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminSearch',
        Data         => {
            %Param,
        },
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _ShowNodeSection {
    my ( $Self, %Param ) = @_;

    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Cluster = $SearchClusterObject->ClusterGet(
        ClusterID => $Param{ClusterID},
    );

    if ( !IsHashRefWithData($Cluster) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Couldn't find cluster data!"
        );
        $LayoutObject->FatalError();
    }

    my $CommunicationNodeObject = $Kernel::OM->Get(
        "Kernel::System::Search::Admin::Node::$Cluster->{EngineID}"
    );

    my $NodeAddView = $CommunicationNodeObject->BuildNodeSection(
        %Param,
        ClusterID => $Param{ClusterID},
        UserID    => $Self->{UserID},
        NodeID    => $Param{NodeID},
        EngineID  => $Cluster->{EngineID},
        Action    => $Param{Action},
    );

    return $NodeAddView;
}

sub _ShowEdit {
    my ( $Self, %Param ) = @_;

    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::Search' => {
            Silent => 1,
        },
    );

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    if ( IsArrayRefWithData( $Param{Notify} ) ) {
        for my $Notification ( @{ $Param{Notify} } ) {
            $Output .= $LayoutObject->Notify(
                %{$Notification},
            );
        }
    }
    elsif ( $Param{Notify} ) {
        $Output .= $LayoutObject->Notify(
            Info => $Param{Notify},
        );
    }

    $LayoutObject->Block(
        Name => 'Main',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionOverview' );

    my $CommunicationNodeList;
    my $ClusterData;

    if ( $Param{Action} eq 'Change' ) {
        $CommunicationNodeList = $SearchClusterObject->ClusterCommunicationNodeList(
            ClusterID => $Param{ClusterID}
        ) // [];

        $LayoutObject->Block(
            Name => 'ActionList',
            Data => {
                CommunicationNodes => $CommunicationNodeList,
                ClusterID          => $Param{ClusterID}
            }
        );

        $LayoutObject->Block(
            Name => 'ActionAddCommunicationNode',
            Data => {
                %Param,
            },
        );

        if ( IsArrayRefWithData($CommunicationNodeList) ) {
            $LayoutObject->Block(
                Name => 'ActionExportCommunicationNodes',
                Data => {
                    ClusterID => $Param{ClusterID},
                },
            );
        }

        $LayoutObject->Block(
            Name => 'ActionDelete',
            Data => \%Param,
        );

        # get cluster configuration
        $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $Param{ClusterID},
        );
    }

    my %GeneralData = (
        Name        => $ClusterData->{Name},
        Description => $ClusterData->{Description},
    );

    my %ValidList = $ValidObject->ValidList();

    my $ValidtyStrg = $LayoutObject->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $ClusterData->{ValidID} || 1,
        PossibleNone => 0,
        Translate    => 1,
        Class        => 'Modernize',
    );

    my $EngineStrg = $LayoutObject->BuildSelection(
        Data         => $Self->{Engines},
        Name         => 'EngineID',
        SelectedID   => $ClusterData->{Engine},
        PossibleNone => 0,
        Translate    => 1,
        Class        => 'Modernize Validate_Required',
    );

    # prevent HTML validation warning
    if ( !$Param{NameServerErrorMessage} ) {
        $Param{NameServerErrorMessage} = '-';
    }

    $LayoutObject->Block(
        Name => 'Details',
        Data => {
            %Param,
            %GeneralData,
            ValidtyStrg        => $ValidtyStrg,
            EngineStrg         => $EngineStrg,
            CommunicationNodes => $CommunicationNodeList,
        },
    );

    # even if there is some configuration error like disabled search engine or
    # no index registered, check for connection when there is valid active engine
    # selected
    if ( $SearchObject->{Error} ) {
        if ( $SearchObject->{Error}->{Configuration} && $SearchObject->{Config}->{ActiveEngine} ) {

            # check and set base modules
            $SearchObject->BaseModulesCheck(
                Config => $SearchObject->{Config},
            );
        }
    }

    my ($ValidID) = grep { $ValidList{$_} eq 'valid' } keys %ValidList;
    for my $CommunicationNode ( @{$CommunicationNodeList} ) {
        $CommunicationNode->{Connection} = $SearchObject->{EngineObject}
            ? $SearchObject->{EngineObject}->CheckNodeConnection(
            %{$CommunicationNode},
            Silent => 1,
            )
            : 0;

        $CommunicationNode->{ValidStr} = $ValidList{ $CommunicationNode->{ValidID} };

        $LayoutObject->Block(
            Name => 'CommunicationNode',
            Data => {
                CommunicationNode => $CommunicationNode,
                ClusterID         => $Param{ClusterID},
                ValidID           => $ValidID,
            },
        );
    }

    my $ActiveClusterConfig = $SearchClusterObject->ActiveClusterGet();

    # check if mandatory fields was set
    my $MandatoryCheckOk = 1;
    MANDATORYPROPERTY:
    for my $MandatoryProperty (qw(Name EngineID)) {
        if ( !$ClusterData->{$MandatoryProperty} ) {
            $MandatoryCheckOk = 0;
            last MANDATORYPROPERTY;
        }
    }

    my $SearchObjectCheckError = $SearchObject->{Error};

    if (
        !$SearchObjectCheckError
        && $MandatoryCheckOk
        && $Self->{Subaction} ne "Add"
        && $ClusterData->{ClusterID}
        && $ClusterData->{ClusterID} eq $ActiveClusterConfig->{ClusterID}
        )
    {
        my $ClusterDetailsObject = $Kernel::OM->Get(
            "Kernel::System::Search::Admin::Details::$ActiveClusterConfig->{Engine}"
        );

        my $Details = $ClusterDetailsObject->BuildDetailsSection(
            ClusterConfig => $ActiveClusterConfig,
            UserID        => $Self->{UserID}
        );

        if (
            $Details->{Synchronize}
            && $SearchObject->{ConnectObject}
            )
        {
            $LayoutObject->Block(
                Name => 'ActionSynchronize',
                Data => {},
            );

            $Output .= $LayoutObject->Notify(
                Info => 'Cluster state needs to be synchronized!',
            );
        }

        $LayoutObject->Block(
            Name => 'DiagnosisDetails',
            Data => {
                Details => $Details->{HTML},
            },
        );
    }
    elsif ($SearchObjectCheckError) {
        my $ErrorMessage;
        my $LanguageObject = $LayoutObject->{LanguageObject};
        if ( $SearchObjectCheckError->{Configuration}->{Disabled} ) {
            $ErrorMessage = $LanguageObject->Translate(
                "Search engine system configuration is disabled."
            );
        }
        elsif ( $SearchObjectCheckError->{Configuration}->{NoIndexRegistered} ) {
            $ErrorMessage = $LanguageObject->Translate(
                "No index registered for engine."
            );
        }
        elsif ( $SearchObjectCheckError->{Configuration}->{ActiveEngineNotFound} ) {
            $ErrorMessage = $LanguageObject->Translate(
                "Active engine not found."
            );
        }
        elsif ( $SearchObjectCheckError->{BaseModules}->{NotFound} ) {
            $ErrorMessage = $LanguageObject->Translate(
                "Base modules for engine was not found."
            );
        }
        elsif ( $SearchObjectCheckError->{Connection}->{Failed} ) {
            $ErrorMessage = $LanguageObject->Translate(
                "Connection failed."
            );
        }

        $LayoutObject->Block(
            Name => 'DiagnosisDetails',
            Data => {
                Details => $ErrorMessage
            },
        );

    }
    else {
        my $ErrorMessage = $LayoutObject->{LanguageObject}->Translate("Engine is not active.");
        $LayoutObject->Block(
            Name => 'DiagnosisDetails',
            Data => {
                Details => $ErrorMessage
            },
        );
    }

    $LayoutObject->Block(
        Name => 'ActionReindexation',
        Data => {
            ClusterID => $ClusterData->{ClusterID}
        },
    );

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminSearch',
        Data         => {
            %Param,
        },
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _ShowReindexation {
    my ( $Self, %Param ) = @_;

    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ReindexationObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Reindexation');

    return $ReindexationObject->BuildReindexationSection(
        ClusterID => $Param{ClusterID},
        UserID    => $Self->{UserID},
    );
}

sub _GetBaseClusterParams {
    my ( $Self, %Param ) = @_;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $GetParam;
    for my $ParamName (
        qw( Name Description ValidID EngineID )
        )
    {
        $GetParam->{$ParamName} = $ParamObject->GetParam( Param => $ParamName ) || '';
    }

    return $GetParam;
}

sub _ClusterSynchronize {
    my ( $Self, %Param ) = @_;

    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchObject        = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');

    NEEDED:
    for my $Needed (qw(ClusterID)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    $LayoutObject->ChallengeTokenCheck();

    my $ActiveClusterConfig = $SearchClusterObject->ActiveClusterGet();

    my $ClusterDetailsObject
        = $Kernel::OM->Get("Kernel::System::Search::Admin::Details::$ActiveClusterConfig->{Engine}");

    my $EngineClusterState = $SearchObject->DiagnosticDataGet();

    if ($EngineClusterState) {
        $ClusterDetailsObject->ClusterStateSet(
            ClusterID    => $Param{ClusterID},
            ClusterState => $EngineClusterState,
            UserID       => $Self->{UserID},
        );
    }

    my $Response = $JSONObject->Encode( Data => $ActiveClusterConfig );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $Response,
        Type        => 'inline',
        NoCache     => 1,
    );
}

=head1 _NodeBaseOperationAction()

base operation action checks for node edit/add screens

    my $Result = $Object->_NodeBaseOperationAction(
        ClusterID => 1,
        NodeID => 2, # optional
        %Params,
    );

=cut

sub _NodeBaseOperationAction {
    my ( $Self, %Param ) = @_;

    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->ChallengeTokenCheck();

    my $GetParam;
    my %Error;

    my %MandatoryFields = (
        Protocol => 1,
        Host     => 1,
        Port     => 1,
        Name     => 1,
        ValidID  => 1,
    );

    # check required parameters
    for my $ParamName (
        qw( Protocol Host Port Path AuthRequired Login Password ClusterID NodeID Name ValidID Comment)
        )
    {
        $GetParam->{$ParamName} = $ParamObject->GetParam( Param => $ParamName ) || '';

        # if is mandatory and was not passed in form
        if ( $MandatoryFields{$ParamName} && $GetParam->{$ParamName} eq '' ) {
            $Error{ $ParamName . 'ServerError' }        = 'ServerError';
            $Error{ $ParamName . 'ServerErrorMessage' } = Translatable('This field is required');
        }
    }

    $GetParam->{AuthRequired} = $GetParam->{AuthRequired} && $GetParam->{AuthRequired} eq 'on' ? 1 : 0;

    if ( $GetParam->{Name} ) {
        my $ClusterCommunicationNodeList = $SearchClusterObject->ClusterCommunicationNodeList(
            ClusterID => $Param{ClusterID},
        );

        my $NameExists = $SearchClusterObject->NodeNameExistsCheck(
            Name      => $GetParam->{Name},
            ClusterID => $Param{ClusterID},
            NodeID    => $Param{NodeID},
        );

        if ($NameExists) {
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('There is another communication node with the same name.');
        }
    }

    if ( $GetParam->{AuthRequired} ) {
        if ( !$GetParam->{Login} ) {
            $Error{LoginServerError}        = 'ServerError';
            $Error{LoginServerErrorMessage} = Translatable('This field is required');
        }
    }
    else {
        undef $GetParam->{Login};
        undef $GetParam->{Password};
    }

    return {
        GetParam => $GetParam,
        Error    => \%Error,
    };
}

1;
