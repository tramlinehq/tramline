// this controller wraps quilljs editor and uses a textarea as a replica to store the content
// it can be used to both create a rich text editor and also render the rich content back
// switch between modes: viewMode=true or viewMode=false for the editor
import {Controller} from "@hotwired/stimulus";
import Quill from "quill"

export default class extends Controller {
  static targets = ["editor", "editorReplica", "viewContents"];

  static values = {
    viewMode: {type: Boolean, default: false},
    viewContent: {type: String},
    placeholder: {type: String, default: "Type something here..."},
  };

  connect() {
    if (this.viewModeValue) {
      this.setContents()
    } else {
      this.setupEditor()
    }
  }

  setContents() {
    if (this.viewContentValue === "") {
      return;
    }

    let transferElement = document.createElement("div")
    const quill = new Quill(transferElement)
    quill.setContents(JSON.parse(this.viewContentValue).ops)
    this.viewContentsTarget.innerHTML = quill.root.innerHTML
  }

  setupEditor() {
    const editor = new Quill(this.editorTarget, this.editorOptions)
    const textArea = this.editorReplicaTarget

    if (textArea.type !== "textarea") {
      console.warn("Your replicaTarget should be a textarea!")
      return;
    }

    if (textArea.value !== "") {
      editor.setContents(JSON.parse(textArea.value).ops)
    }

    editor.on("text-change", function() {
      let delta = editor.getContents()
      textArea.value = JSON.stringify(delta)
    })
  }

  get editorOptions() {
    return {
      modules: {
        toolbar: this.editorToolbarOptions
      },
      placeholder: this.placeholderValue,
      readOnly: false,
      theme: "snow",
      formats: [
        'background',
        'bold',
        'color',
        'italic',
        'link',
        'list',
        'size',
        'strike',
        'underline',
        'blockquote',
        'align',
        'code-block',
      ]
    }
  }

  get editorToolbarOptions() {
    return {
      container: [
        [{ 'size': ['small', false, 'large', 'huge'] }],
        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
        [{ 'align': [] }],
        ['clean'],
        ['bold', 'italic', 'underline', 'strike'],
        ['link', 'blockquote', 'code-block'],
        [{ 'color': [] }, { 'background': [] }],
      ]
    }
  }
}
