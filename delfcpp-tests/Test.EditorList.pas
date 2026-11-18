unit Test.EditorList;

{ EditorList's layout: which page controls show, and which editors are visible, from how many
  tabs each side has. Driven through its own interface with page controls that have no window
  (a form never shown, no TEditor): each tab sheet's Tag holds a stand-in object where an editor would be;
  GetEditor only casts the Tag, it never uses the editor.

  Category "Characterization": the layout for each combination of left and right tabs.
  Category "Regression": DELF-JOURNEY.md error 12: in a split view GetVisibleEditors gave the
  left editor as the right one too. }

interface

uses
  DUnitX.TestFramework, System.Classes, Vcl.Forms, Vcl.ComCtrls, Vcl.ExtCtrls, Editor, EditorList;

type
  [TestFixture]
  TEditorListTests = class
  private
    fList: TEditorList;
    fForm: TForm; // never shown: tab sheets need a parent window
    fLeft, fRight: TPageControl;
    fPanel: TPanel;
    fSplitter: TSplitter;
    fLeftEditor, fRightEditor: TObject;
    procedure NoChange(Sender: TObject);
    procedure AddTab(Control: TPageControl; Editor: TObject);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] [Category('Characterization')]
    [TestCase('no tabs', '0,0,none')]
    [TestCase('left only', '1,0,left')]
    [TestCase('right only', '0,1,right')]
    [TestCase('both', '1,1,both')]
    procedure Layout(const LeftTabs, RightTabs: Integer; const Expected: string);

    [Test] [Category('Regression')]
    procedure SplitViewVisibleEditors;
  end;

implementation

uses
  System.SysUtils;

const
  LayoutNames: array[TLayoutShowType] of string = ('none', 'left', 'right', 'both');

procedure TEditorListTests.NoChange(Sender: TObject);
begin
  // ShowLayout(lstNone) calls the left page control's OnChange, which the app always sets
end;

procedure TEditorListTests.AddTab(Control: TPageControl; Editor: TObject);
var
  Sheet: TTabSheet;
begin
  Sheet := TTabSheet.Create(Control);
  Sheet.PageControl := Control;
  Sheet.Tag := NativeInt(Editor);
  Control.ActivePage := Sheet;
end;

procedure TEditorListTests.Setup;
begin
  fForm := TForm.CreateNew(nil);
  fPanel := TPanel.Create(fForm);
  fPanel.Parent := fForm;
  fLeft := TPageControl.Create(fForm);
  fLeft.Parent := fPanel;
  fRight := TPageControl.Create(fForm);
  fRight.Parent := fPanel;
  fSplitter := TSplitter.Create(fForm);
  fSplitter.Parent := fPanel;
  fLeft.OnChange := NoChange;
  fLeftEditor := TObject.Create;
  fRightEditor := TObject.Create;
  fList := TEditorList.Create;
  fList.Panel := fPanel;
  fList.LeftPageControl := fLeft;
  fList.RightPageControl := fRight;
  fList.Splitter := fSplitter;
end;

procedure TEditorListTests.TearDown;
begin
  fList.Free;
  fForm.Free; // and the controls it owns
  fLeftEditor.Free;
  fRightEditor.Free;
end;

procedure TEditorListTests.Layout(const LeftTabs, RightTabs: Integer; const Expected: string);
var
  I: Integer;
begin
  // From "both", so that every expected layout is a change (ShowLayout skips no change)
  AddTab(fLeft, fLeftEditor);
  AddTab(fRight, fRightEditor);
  fList.UpdateLayout;
  Assert.AreEqual('both', LayoutNames[fList.Layout]);
  for I := fLeft.PageCount - 1 downto LeftTabs do
    fLeft.Pages[I].Free;
  for I := fRight.PageCount - 1 downto RightTabs do
    fRight.Pages[I].Free;
  fList.UpdateLayout;
  Assert.AreEqual(Expected, LayoutNames[fList.Layout]);
end;

procedure TEditorListTests.SplitViewVisibleEditors;
var
  L, R: TEditor;
begin
  AddTab(fLeft, fLeftEditor);
  AddTab(fRight, fRightEditor);
  fList.UpdateLayout;
  fList.GetVisibleEditors(L, R);
  Assert.AreSame(fLeftEditor, TObject(L), 'left');
  Assert.AreSame(fRightEditor, TObject(R), 'right: the original gave the left editor here too');
end;

initialization
  TDUnitX.RegisterTestFixture(TEditorListTests);

end.
