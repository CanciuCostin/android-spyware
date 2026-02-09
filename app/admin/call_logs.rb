ActiveAdmin.register CallLog do
  menu parent: "📦 Data", priority: 2, label: "📞 Call Logs"
	permit_params :filename,
								:smartphone_id,
								:date,
								:'date(1i)',
								:'date(2i)',
								:'date(3i)'

	includes :smartphone

	form do |f|
		f.semantic_errors

		f.inputs do
			f.input :smartphone, collection: Smartphone.all, include_blank: false
			f.input :date, as: :string, input_html: { type: :date }
			f.input :filename
		end

		f.actions
	end
end
