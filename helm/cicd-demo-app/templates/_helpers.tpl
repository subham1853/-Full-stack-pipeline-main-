{{/*
╦ ╦╔═╗╔═╗╔╦╗╔═╗╔╦╗  ╔╦╗╔═╗╔═╗╔╦╗
║ ║╚═╗║╣  ║║╠═╝ ║    ║║║╣ ╠═╣ ║║
╚═╝╚═╝╚═╝═╩╝╩   ╩   ═╩╝╚═╝╩ ╩═╩╝
Helm Chart Helper Templates
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "cicd-demo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cicd-demo-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cicd-demo-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cicd-demo-app.labels" -}}
helm.sh/chart: {{ include "cicd-demo-app.chart" . }}
{{ include "cicd-demo-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cicd-demo-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cicd-demo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cicd-demo-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cicd-demo-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "cicd-demo-app.image" -}}
{{- $registryName := .Values.global.imageRegistry | default "" -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s%s:%s" $registryName $repositoryName $tag -}}
{{- end }}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "cicd-demo-app.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image) "global" .Values.global) -}}
{{- end }}

{{/*
Create the name of the configmap
*/}}
{{- define "cicd-demo-app.configMapName" -}}
{{- printf "%s-config" (include "cicd-demo-app.fullname" .) -}}
{{- end }}

{{/*
Create the name of the secret
*/}}
{{- define "cicd-demo-app.secretName" -}}
{{- printf "%s-secrets" (include "cicd-demo-app.fullname" .) -}}
{{- end }}
