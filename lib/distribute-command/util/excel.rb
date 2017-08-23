module Excel
  class Application
    def initialize
      WIN32OLE.ole_initialize

      @application = WIN32OLE.new 'Excel.Application'
    end

    def add template = nil
      if template.nil?
        WorkBook.new @application.WorkBooks.Add
      else
        if File.file? template
          WorkBook.new @application.WorkBooks.Add(File.expand_path(template).gsub('/', '\\'))
        else
          nil
        end
      end
    end

    def open file
      if File.file? file
        WorkBook.new @application.WorkBooks.Open(File.expand_path(file).gsub('/', '\\'))
      else
        nil
      end
    end

    def quit
      begin
        @application.Quit
        @application.ole_free
      rescue
      end

      @application = nil
      GC.start
    end

    def self.excel? file
      ['.xls', '.xlsx'].include? File.extname(file).downcase
    end
  end

  class WorkBook
    def initialize workbook
      @workbook = workbook
    end

    def worksheet index = 1
      WorkSheet.new @workbook.WorkSheets(index)
    end

    def save file = nil
      if file.nil?
        @workbook.Save
      else
        if not Application.excel? file
          if @workbook.application.Version.to_i > 11
            file += '.xlsx'
          else
            file += '.xls'
          end
        end

        if File.file? file
          File.delete file
        end

        if File.mkdir File.dirname(file)
          @workbook.SaveAs File.expand_path(file).gsub('/', '\\')
        else
          false
        end
      end
    end

    def close save = false
      @workbook.Close save
    end
  end

  class WorkSheet
    attr_reader :worksheet

    def initialize worksheet
      @worksheet = worksheet
    end

    def data max_rows = 0, max_columns = 0
      data = []

      @worksheet.UsedRange.Rows.Count.times do |i|
        line_data = []

        if max_rows > 0
          if i >= max_rows
            break
          end
        end

        @worksheet.UsedRange.Columns.Count.times do |j|
          if max_columns > 0
            if j >= max_columns
              break
            end
          end

          line_data << get(i + 1, j + 1)
        end

        data << line_data
      end

      data
    end

    def get row, col
      @worksheet.Cells(row, col).Value.to_s.utf8.strip
    end

    def set row, col, val
      if val.to_s.nil.nil?
        @worksheet.Cells(row, col).Clear
      else
        @worksheet.Cells(row, col).Value = val.to_s.locale
      end
    end
  end
end