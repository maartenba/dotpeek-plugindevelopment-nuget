<?xml version="1.0" encoding="utf-8" ?>
<actions>
  <action id="$rootnamespace$.CommandWindowAction" text="Open command window" />
  <action id="$rootnamespace$.AboutAction" text="About $rootnamespace$..." />

  <insert group-id="DotPeek.File" position="before" anchor-id="AssemblyExplorerAddItem">
    <action-group id="$rootnamespace$.File" text="$rootnamespace$">
        <action-ref id="$rootnamespace$.CommandWindowAction" />
        <action-ref id="$rootnamespace$.AboutAction" />
    </action-group>
    <action-ref id="$rootnamespace$.CommandWindowAction" />
    <separator />
  </insert>
</actions>