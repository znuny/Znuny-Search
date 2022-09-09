# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
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

    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $ClusterID = $ParamObject->GetParam( Param => 'ClusterID' ) || '';

    if ( $Self->{Subaction} eq 'Change' ) {

        # check for ClusterID param
        if ( !$ClusterID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ClusterID !'),
            );
        }

        # get cluster configuration
        my $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $ClusterID,
        );

        # check for valid cluster configuration
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
        my $Exists;

        if ( !$ClusterData{Name} ) {

            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('This field is required.');
        }
        else {
            # check if name is duplicated
            $Exists = $SearchClusterObject->NameExistsCheck(
                ID   => $ClusterID,
                Name => $ClusterData{Name},
            );
        }

        if ($Exists)
        {
            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('There is another cluster with the same name.');
        }

        # if there is an error return to edit screen
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

        # show error if cant update
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
        else {

            # otherwise return to overview
            return $LayoutObject->Redirect( OP => "Action=$Self->{Action}" );
        }
    }

    if ( $Self->{Subaction} eq 'Add' ) {
        return $Self->_ShowEdit(
            Action => 'Add',
        );

    }
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get cluster configuration
        my $ClusterData;

        # get parameter from web browser
        my $GetParam = $Self->_GetBaseClusterParams();

        # set new configuration
        $ClusterData->{Name}        = $GetParam->{Name};
        $ClusterData->{Description} = $GetParam->{Description};
        $ClusterData->{EngineID}    = $GetParam->{EngineID};
        $ClusterData->{ValidID}     = $GetParam->{ValidID};

        my %Error;
        my $Exists;

        if ( !$GetParam->{Name} ) {

            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('This field is required.');
        }
        else {
            # check if name is duplicated
            $Exists = $SearchClusterObject->NameExistsCheck(
                ID   => $ClusterID,
                Name => $GetParam->{Name},
            );
        }

        if ( !$GetParam->{EngineID} ) {

            # add server error error class
            $Error{EngineIDError}        = 'ServerError';
            $Error{EngineIDErrorMessage} = Translatable('This field is required.');
        }

        if ($Exists)
        {

            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('There is another cluster with the same name.');
        }

        # if there is an error return to edit screen
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

        # otherwise save configuration and return to overview screen
        my $ID = $SearchClusterObject->ClusterAdd(
            Name        => $ClusterData->{Name},
            ValidID     => $ClusterData->{ValidID},
            Description => $ClusterData->{Description},
            EngineID    => $ClusterData->{EngineID},
            UserID      => $Self->{UserID},
        );

        # show error if cant create
        if ( !$ID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('There was an error creating the cluster.'),
            );
        }

        # set ClusterID to the new created cluster
        $ClusterID = $ID;

        # define notification
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

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get cluster configuration
        my $ClusterData = $SearchClusterObject->ClusterGet(
            ClusterID => $ClusterID,
        );

        my $Success = $SearchClusterObject->ClusterDelete(
            ClusterID => $ClusterID,
            UserID    => $Self->{UserID},
        );

        # build JSON output
        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success        => $Success,
                DeletedCluster => $ClusterData->{Name},
            },
        );

        # send JSON response
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

        # if there is an error return to add communication node screen
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

            # add server error error class
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

        # if there is an error return to add/edit communication node screen
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

            # add server error error class
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
        else {

            return $Self->_ShowEdit(
                ClusterID => $ClusterID,
                Action    => 'Change',
            );
        }

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

        # Create new node name.
        my $Count    = 1;
        my $NodeName = $LayoutObject->{LanguageObject}->Translate( '%s (copy) %s', $NodeData->{Name}, $Count );

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

        # challenge token check for write action
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

        # build JSON output
        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Success => $Success,
            },
        );

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    if ( $Self->{Subaction} eq 'TestNodeConnection' ) {

        my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $EngineObject = $Kernel::OM->Get("Kernel::System::Search::Engine::ES");
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

        my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $YAMLObject  = $Kernel::OM->Get('Kernel::System::YAML');

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

        # send the result to the browser
        return $LayoutObject->Attachment(
            ContentType => 'text/html; charset=' . $LayoutObject->{Charset},
            Content     => $NodesDataYAML,
            Type        => 'attachment',
            Filename    => $Filename,
            NoCache     => 1,
        );

    }
    if ( $Self->{Subaction} eq 'ClusterNodeImport' ) {

        # challenge token check for write action
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
                'The following nodes have been added successfully: %s',
                $NodesImport->{AddedNodes}
            );
            push @{ $Param{Notify} }, {
                Info => $Info
            };
        }
        if ( $NodesImport->{UpdatedNodes} ) {
            my $Info = $LayoutObject->{LanguageObject}->Translate(
                'The following nodes have been updated successfully: %s',
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

    my $DeletedCluster = $ParamObject->GetParam( Param => 'DeletedCluster' ) || '';

    my $Notify;

    if ($DeletedCluster) {

        # define notification
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
            Link => $LayoutObject->{Baselink} . 'Action=AdminSystemConfiguration;Subaction=View;Setting=SearchEngine;'
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
        CLUSTER:
        for my $ClusterID (
            sort { $ClusterList->{$a} cmp $ClusterList->{$b} }
            keys %{$ClusterList}
            )
        {
            next CLUSTER if !$ClusterID;

            my $Cluster = $SearchClusterObject->ClusterGet( ClusterID => $ClusterID );
            next CLUSTER if !$Cluster;

            # convert ValidID to text
            my $ValidStrg = $ValidObject->ValidLookup(
                ValidID => $Cluster->{ValidID},
            );

            # Engine isn't in the configuration
            if ( !$Self->{Engines}->{ $Cluster->{EngineID} } ) {
                $Self->{Engines}->{ $Cluster->{EngineID} } = 'Unregistered';
            }

            # prepare data to output
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

    my $NodeAddViev = $CommunicationNodeObject->BuildNodeSection(
        %Param,
        ClusterID => $Param{ClusterID},
        UserID    => $Self->{UserID},
        NodeID    => $Param{NodeID},
        EngineID  => $Cluster->{EngineID},
        Action    => $Param{Action},
    );

    return $NodeAddViev;
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

    # show notifications if any
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

    # create the validity select
    my $ValidtyStrg = $LayoutObject->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $ClusterData->{ValidID} || 1,
        PossibleNone => 0,
        Translate    => 1,
        Class        => 'Modernize',
    );

    # create the validity select
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
    MANDATORY:
    for my $MandatoryProperty (qw(Name EngineID)) {
        if ( !$ClusterData->{$MandatoryProperty} ) {
            undef $MandatoryCheckOk;
            last MANDATORY;
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

        if ( ( $Details->{Synchronize} ) && $SearchObject->{ConnectObject} ) {
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

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminSearch',
        Data         => {
            %Param,
        },
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _GetBaseClusterParams {
    my ( $Self, %Param ) = @_;

    my $GetParam;
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get parameters from web browser
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

    # challenge token check for write action
    $LayoutObject->ChallengeTokenCheck();

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

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

=head2 _NodeBaseOperationAction()

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

    # challenge token check for write action
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

    if ( $GetParam->{AuthRequired} ) {
        if ( $GetParam->{AuthRequired} eq 'on' ) {
            $GetParam->{AuthRequired} = 1;
        }
        elsif ( $GetParam->{AuthRequired} eq 'off' ) {
            $GetParam->{AuthRequired} = 0;
        }
    }

    if ( $GetParam->{Name} ) {

        # check if name is duplicated
        my $ClusterCommunicationNodeList = $SearchClusterObject->ClusterCommunicationNodeList(
            ClusterID => $Param{ClusterID},
        );

        my $Exist = $SearchClusterObject->NodeNameExistsCheck(
            Name      => $GetParam->{Name},
            ClusterID => $Param{ClusterID},
            NodeID    => $Param{NodeID},
        );

        if ($Exist) {

            # add server error error class
            $Error{NameServerError}        = 'ServerError';
            $Error{NameServerErrorMessage} = Translatable('There is another communication node with the same name.');
        }
    }

    if ( $GetParam->{AuthRequired} ) {

        if ( !$GetParam->{Login} ) {

            # add server error error class
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
