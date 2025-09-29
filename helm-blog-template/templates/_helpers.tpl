{{/*
Expand the name of the chart.
*/}}
{{- define "blog-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "blog-template.fullname" -}}
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
{{- define "blog-template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "blog-template.labels" -}}
helm.sh/chart: {{ include "blog-template.chart" . }}
{{ include "blog-template.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
client: {{ .Values.client.name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "blog-template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "blog-template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "blog-template.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "blog-template.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate passwords and secrets
*/}}
{{- define "blog-template.mysql.password" -}}
{{- if .Values.env.database.password }}
{{- .Values.env.database.password }}
{{- else }}
{{- randAlphaNum 32 | b64enc }}
{{- end }}
{{- end }}

{{- define "blog-template.redis.password" -}}
{{- if .Values.env.redis.password }}
{{- .Values.env.redis.password }}
{{- else }}
{{- randAlphaNum 32 | b64enc }}
{{- end }}
{{- end }}

{{- define "blog-template.elasticsearch.password" -}}
{{- if .Values.env.elasticsearch.password }}
{{- .Values.env.elasticsearch.password }}
{{- else }}
{{- randAlphaNum 32 | b64enc }}
{{- end }}
{{- end }}

{{- define "blog-template.jwt.secret" -}}
{{- if .Values.env.app.jwtSecret }}
{{- .Values.env.app.jwtSecret }}
{{- else }}
{{- randAlphaNum 64 | b64enc }}
{{- end }}
{{- end }}

{{- define "blog-template.session.secret" -}}
{{- if .Values.env.app.sessionSecret }}
{{- .Values.env.app.sessionSecret }}
{{- else }}
{{- randAlphaNum 64 | b64enc }}
{{- end }}
{{- end }}

{{/*
Generate service names
*/}}
{{- define "blog-template.mysql.serviceName" -}}
{{- printf "%s-mysql" .Release.Name }}
{{- end }}

{{- define "blog-template.redis.serviceName" -}}
{{- printf "%s-redis" .Release.Name }}
{{- end }}

{{- define "blog-template.elasticsearch.serviceName" -}}
{{- printf "%s-elasticsearch" .Release.Name }}
{{- end }}

{{- define "blog-template.mailcrab.serviceName" -}}
{{- printf "%s-mailcrab" .Release.Name }}
{{- end }}

{{- define "blog-template.backend.serviceName" -}}
{{- printf "%s-backend" .Release.Name }}
{{- end }}

{{- define "blog-template.frontend.serviceName" -}}
{{- printf "%s-frontend" .Release.Name }}
{{- end }}

{{/*
Generate full DNS names for services
*/}}
{{- define "blog-template.mysql.fullname" -}}
{{- printf "%s.%s.svc.cluster.local" (include "blog-template.mysql.serviceName" .) .Values.client.namespace }}
{{- end }}

{{- define "blog-template.redis.fullname" -}}
{{- printf "%s.%s.svc.cluster.local" (include "blog-template.redis.serviceName" .) .Values.client.namespace }}
{{- end }}

{{- define "blog-template.elasticsearch.fullname" -}}
{{- printf "%s.%s.svc.cluster.local" (include "blog-template.elasticsearch.serviceName" .) .Values.client.namespace }}
{{- end }}

{{- define "blog-template.mailcrab.fullname" -}}
{{- printf "%s.%s.svc.cluster.local" (include "blog-template.mailcrab.serviceName" .) .Values.client.namespace }}
{{- end }}
